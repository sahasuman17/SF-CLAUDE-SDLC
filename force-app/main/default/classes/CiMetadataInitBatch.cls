/**
 * @name        CiMetadataInitBatch
 * @description Batch to initialize CI metadata snapshot via SmartSyncInitializer.createCiMetaSnapshots().
 *              Includes retry mechanism based on Generic_Key_Value__mdt and publishes platform event result.
 * @author      Debanjan Mukherjee
 * @created     2025-06-26
 */
global without sharing class CiMetadataInitBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
    private Integer retryCount;
	private string errMessage = '';
    @testVisible public static boolean forceFailed = false;
    /**
     * @description Custom exception for Metadata failures
     */
    public class MetadataInitException extends Exception {}
    /**
     * @description Default constructor, initializes retry to 0
     */
    public CiMetadataInitBatch() {
        this.retryCount = 0;
        this.errMessage = '';
    }

    /**
     * @description Overloaded constructor for retry batch run
     * @param retryCount Current retry count
     */
    public CiMetadataInitBatch(Integer retryCount) {
        this.retryCount = retryCount;
        this.errMessage = '';
    }
    /**
     * @description Dummy start method with 1-record scope for one-time execution
    * @param bc Batchable context
     * @return QueryLocator for the current user
     * @note This is a dummy implementation to ensure the batch runs once.
     *       It fetches the current user record to trigger the batch execution.
     *       The actual logic is in the execute method.
     *       This method is required by the Database.Batchable interface.
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM User WHERE Id = :UserInfo.getUserId()
        ]);
    }
    /**
     * @description Attempts to fetch CI metadata snapshot via SmartSyncInitializer
    * @param bc Batchable context
        * @param scope List of SObjects (not used, but required by Database.Batchable interface)
        * @note This method is called for each batch execution.
     */
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            Set<String> cioNames = SmartSyncInitializer.createCiMetaSnapshots();
        } catch (Exception ex) {
            errMessage = errMessage+ex.getMessage();
        }
    }
    /**
     * @description Handles retry and result publication post execution
        * @param bc Batchable context
        * @note This method is called after all batches are processed.
     */
    global void finish(Database.BatchableContext bc) {
        Boolean hasFailed = false;
        String errorMessage = errMessage;
		Exception theException;
        try {
            AsyncApexJob job = [
                SELECT Id, Status, NumberOfErrors
                FROM AsyncApexJob
                WHERE Id = :bc.getJobId()
                LIMIT 1
            ];
            hasFailed = (job.NumberOfErrors > 0);
            if(Test.isRunningTest() && forceFailed)
            {
                throw new MetadataInitException('Force exception for Apex Test');
            }
        } catch (Exception ex) {
            hasFailed = true;
            theException = ex;
        }
        Integer maxRetries = getRetrySetting('Max_Metadata_Retries');
        Integer retryInterval = getRetrySetting('Metadata_Processing_Retry_Interval');
        if (hasFailed) {
            errorMessage = 'Metadata initialization failed.';
            if (retryCount < maxRetries) {
                errorMessage += ' We will retry after ' + retryInterval + ' min.';
                System.schedule(
                    'Retry_Metadata_Init_' + Datetime.now().getTime(),
                    buildCronAfterMinutes(retryInterval),
                    new CiMetadataInitBatch(retryCount + 1)
                );
            } else {
                errorMessage = 'Error fetching Calculated Insights from Data Cloud. Maximum retries with ' + maxRetries + ' times failed. Giving up.';
            }
            SmartSyncUtil.publishEvent(
                    'SyncFailed',
                    errorMessage,
                     'Error'
                );
            ErrorLogger.logErrorFromException('High', 'CiMetadataInitBatch', 'Finish',theException, errorMessage);
        }else
        {
            ErrorLogger.logErrorFromException('Low', 'CiMetadataInitBatch', 'Finish',null, 'Success Fetching Caluclated Insights');
            SmartSyncUtil.publishEvent(
                    'Initialize',
                    '',
                    'Success'
                );
        }
    }
    /**
     * @description Builds cron expression for future scheduling
     * @param minutes Minutes from now to schedule
     * @return Cron expression string
    */
    private String buildCronAfterMinutes(Integer minutes) {
        Datetime dt = Datetime.now().addMinutes(minutes);
        return String.format('{0} {1} {2} {3} {4} ?',
            new List<String>{
                String.valueOf(dt.second()),
                String.valueOf(dt.minute()),
                String.valueOf(dt.hour()),
                String.valueOf(dt.day()),
                String.valueOf(dt.month())
            }
        );
    }
    /**
     * @description Retrieves retry metadata from Generic_Key_Value__mdt
     * @param keyName Metadata key (e.g. Max_Retries__c)
     * @return Parsed Integer value
    * @note This method reads the Generic_Key_Value__mdt custom metadata type to get retry settings.
     */
    @TestVisible
    private Integer getRetrySetting(String keyName) {
        try {
            List<Generic_Key_Value__mdt> entries = [
                SELECT Value__c FROM Generic_Key_Value__mdt
                WHERE Key__c = :keyName LIMIT 1
            ];
            if (!entries.isEmpty()) {
                return Integer.valueOf(entries[0].Value__c);
            }
        } catch (Exception e) {
            // $&
        }
        return 1; // default fallback
    }
    /**
     * @description Scheduler interface implementation
     * @param sc Context
     */
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new CiMetadataInitBatch(), 1);
    }


}