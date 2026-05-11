/**
 * @name        CIMetadataFieldBatchProcessor
 * @description Batch class to create fields via Metadata API for a Calculated Insight object.
 *              It includes built-in retry, error handling, sync tracking, and permission set updates.
 *              This version uses generic SObject batching and includes internal schedulable logic.
 * @author      Debanjan Mukherjee
 * @created     2025-06-25
 */
public with sharing class CIMetadataFieldBatchProcessor implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private final String ciName;
    private final String permissionSetName;
    private final Integer retryCount;
    private final String objectApiName;
    private Boolean anyFailure = false;
    private String collectedErrors = '';
	@testVisible public static boolean forceException = false;
    /**
     * @description Custom exception for Metadata failures
     */
    public class MetadataServiceException extends Exception {}
    /**
     * @description Constructor to initialize batch with target CI name and permission set.
     * @param ciName Developer name of the Calculated Insight object (without __c)
     * @param permissionSetName Name of the permission set to update access on
     * @param retryCount Number of retries so far
     */
    public CIMetadataFieldBatchProcessor(String ciName, String permissionSetName, Integer retryCount) {
        this.ciName = ciName;
        this.permissionSetName = permissionSetName;
        this.retryCount = retryCount;
        if(this.ciName.endsWith('__c'))
            this.objectApiName = ciName;
        else
            this.objectApiName = ciName + '__c';
    }
    /**
     * @description Starts the batch process by querying Insight_Field__c records for the specified CI.
     *              Validates if the CI object exists and initializes error handling.
     * @param context Batchable context
     * @return QueryLocator for Insight_Field__c records related to the specified CI
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
            anyFailure = true;
            collectedErrors = 'Object not found: ' + objectApiName;
            return Database.getQueryLocator([SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]);
        }

        return Database.getQueryLocator([
            SELECT Id, Name, Calculated_Insight__c, Developer_Name__c, displayName__c, field_type__c,
                   Calculated_Insight__r.displayName__c, Calculated_Insight__r.Developer_Name__c
            FROM Insight_Field__c
            WHERE Calculated_Insight__r.Developer_Name__c = :ciName
        ]);
    }
    /**
     * @description Processes each batch of Insight_Field__c records to create metadata fields.
     *              Handles both standard and number field types, collects errors, and updates status.
     * @param context Batchable context
     * @param scope List of SObjects (Insight_Field__c) to process in this batch
     */
    public void execute(Database.BatchableContext context, List<SObject> scope) {
        try {
            List<Insight_Field__c> insightFields = new List<Insight_Field__c>();
            for (SObject sObj : scope) {
                if (sObj instanceof Insight_Field__c) {
                    insightFields.add((Insight_Field__c) sObj);
                }
            }

            List<MetaDataServiceHandler.fieldDef> fields = prepareFields(objectApiName, insightFields);
            List<MetaDataServiceHandler.fieldDefNumber> numFields = prepareNumFields(objectApiName, insightFields);
            MetaDataServiceHandler.createFields(fields,numFields);
        } catch (Exception ex) {
            anyFailure = true;
            collectedErrors += 'Field creation failed: ' + ex.getMessage() + '\n';
        }
    }
    /**
     * @description Finalizes the batch process by checking for errors, updating permission sets,
     *              and scheduling retries if necessary. Publishes events for sync status.
     * @param context Batchable context
     */
    public void finish(Database.BatchableContext context) {
        Boolean hasFailed = false;
        Exception theException;
        try {
            if (anyFailure) {
                retryOrFail();
            }
            try
            {
                PermissionSetUpdater.grantFullAccessToPermissionSet(objectApiName, permissionSetName);
            }Catch(Exception ex)
            {
                throw new MetadataServiceException('PermissionSetUpdater grantFullAccessToPermissionSet issue');
            }
            if(!Test.isRunningTest()){
                Database.executeBatch(new CIBatchProcessor(ciName, false, 0, 3, 0,0), 1);}
            AsyncApexJob job = [
                SELECT Id, Status, NumberOfErrors
                FROM AsyncApexJob
                WHERE Id = :context.getJobId()
                LIMIT 1
            ];
            hasFailed = (job.NumberOfErrors > 0);
            if(Test.isRunningTest() && forceException)
            {
                throw new MetadataServiceException('Forced exception from Apex Test');
            }
        } catch (Exception ex) {
            hasFailed = true;
            theException = ex;
        }
        if (hasFailed) {
            collectedErrors = 'Object creation failure '+collectedErrors;
            ErrorLogger.logErrorFromException('High', 'CIMetadataFieldBatchProcessor', 'Finish',theException, collectedErrors);
        	SmartSyncUtil.publishEvent(
                    'Full Sync',
                     collectedErrors,
                	'Error'
                );
        }
    }
    /**
     * @description Handles retry logic or failure notification based on retry count.
     *              If retries are available, schedules the next run; otherwise, logs the error.
     */
    private void retryOrFail() {
        Integer maxRetries = getIntegerConfigValue('Max_Metadata_Retries');
        Integer retryInterval = getIntegerConfigValue('Metadata_Processing_Retry_Interval');

        if (retryCount < maxRetries) {
            Datetime nextRun = Datetime.now().addMinutes(retryInterval);
            String cron = String.format('0 {0} {1} {2} {3} ? {4}',
                new List<String>{
                    String.valueOf(nextRun.minute()),
                    String.valueOf(nextRun.hour()),
                    String.valueOf(nextRun.day()),
                    String.valueOf(nextRun.month()),
                    String.valueOf(nextRun.year())
                }
            );

            String jobName = 'Retry_Metadata_CI_' + objectApiName + '_' + DateTime.now().getTime();
            System.schedule(jobName, cron, new RetryScheduler(ciName, permissionSetName, retryCount + 1));
        }
    }
/**
     * @description Helper to convert Insight_Field__c list into metadata field definitions.
     *              Excludes NUMBER type fields and prepares Text/LongTextArea fields.
     * @param objectAPI API name of the object to which fields belong
     * @param insightFields List of Insight_Field__c records to process
     * @return List of field definitions for metadata creation
     */
    public static List<MetaDataServiceHandler.fieldDef> prepareFields(String objectAPI, List<Insight_Field__c> insightFields) {
        List<MetaDataServiceHandler.fieldDef> fieldDefs = new List<MetaDataServiceHandler.fieldDef>();
        for (Insight_Field__c f : insightFields) {
            if(f.field_type__c !='NUMBER')
            {
            	MetaDataServiceHandler.fieldDef def = new MetaDataServiceHandler.fieldDef();
                def.fullName = objectAPI + '.' + f.Name;
                def.label = f.displayName__c;
                def.type_x = f.field_type__c;

                if (def.type_x == 'LongTextArea') {
                    def.length = 32000;
                } else if (def.type_x == 'STRING') {
                    def.type_x = 'Text';
                    def.length = 255;
                } else if (def.type_x == 'DATE') {
                    def.type_x = 'Date';
                    def.length = null; // Length not applicable
                } else if (def.type_x == 'DATE_TIME') {
                    def.type_x = 'DateTime';
                    def.length = null; // Length not applicable
                }
                else if (def.type_x == 'DATETIME') {
                    def.type_x = 'DateTime';
                    def.length = null; // Length not applicable
                }
                else {
                    def.type_x = 'Text';
                    def.length = 255;
                }
                fieldDefs.add(def);
            }
        }
        return fieldDefs;
    }
    /**
     * @description Helper to convert Insight_Field__c list into metadata field definitions for NUMBER type fields.
     *              Prepares field definitions with precision and scale.
     * @param objectAPI API name of the object to which fields belong
     * @param insightFields List of Insight_Field__c records to process
     * @return List of field definitions for NUMBER type metadata creation
     */
    public List<MetaDataServiceHandler.fieldDefNumber> prepareNumFields(String objectAPI, List<Insight_Field__c> insightFields) {
        List<MetaDataServiceHandler.fieldDefNumber> fieldDefs = new List<MetaDataServiceHandler.fieldDefNumber>();
        for (Insight_Field__c f : insightFields) {
            if(f.field_type__c =='NUMBER')
            {
            	MetaDataServiceHandler.fieldDefNumber def = new MetaDataServiceHandler.fieldDefNumber();
                def.fullName = objectAPI + '.' + f.Name;
                def.label = f.displayName__c;
                def.type_x = 'Number';
                def.precision = 16;  // Total digits
                def.scale = 2;      // Digits after decimal
                fieldDefs.add(def);
            }
        }
        return fieldDefs;
    }
    /**
     * @description Retrieves an integer configuration value from Generic_Key_Value__mdt metadata.
     *              Returns a default value of 1 if the key is not found or the value is blank.
     * @param key The key to look up in the metadata
     * @return Integer value associated with the key, or 1 if not found
     */
    private Integer getIntegerConfigValue(String key) {
        List<Generic_Key_Value__mdt> rows = [
            SELECT Value__c FROM Generic_Key_Value__mdt WHERE Key__c = :key LIMIT 1
        ];
        if (!rows.isEmpty() && String.isNotBlank(rows[0].Value__c)) {
            return Integer.valueOf(rows[0].Value__c);
        }
        return 1;
    }
    /**
     * @name        RetryScheduler
     * @description Schedulable class to execute CIMetadataFieldBatchProcessor with retry logic
     * @implements  Schedulable
     * @author      Debanjan Mukherjee
     * @created     2025-06-25
     */
    public class RetryScheduler implements Schedulable {
        private final String retryCiName;
        private final String retryPermissionSet;
        private final Integer newRetryCount;
        /**
         * @description Constructor to initialize the retry scheduler with CI name, permission set, and retry count.
         * @param ciName Developer name of the Calculated Insight object (without __c)
         * @param permissionSetName Name of the permission set to update access on
         * @param retryCount Number of retries so far
         */
        public RetryScheduler(String ciName, String permissionSetName, Integer retryCount) {
            this.retryCiName = ciName;
            this.retryPermissionSet = permissionSetName;
            this.newRetryCount = retryCount;
        }
        /**
         * @description Executes the batch job with the provided parameters.
         *              This method is called by the scheduler to start the batch process.
         * @param context Schedulable context
         */
        public void execute(SchedulableContext context) {
            Database.executeBatch(
                new CIMetadataFieldBatchProcessor(retryCiName, retryPermissionSet, newRetryCount),
                10
            );
        }
    }


}