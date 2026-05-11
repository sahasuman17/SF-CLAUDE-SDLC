/**
 * IncrementBatch orchestrates polling and processing of Data Cloud Bulk API jobs.
 * @description
 * This class is designed to:
 * - Launch a Bulk API job using objectApiName.
 * - Poll and fetch job status and result.
 * - Retry failed jobs with configurable limits and intervals.
 * - Use CsvLineProcessorBatch to parse and persist results from job.
 * - Leverage metadata values under 'Incremental_Sync' for retry configuration.
 *
 * It supports execution via both batch and schedulable interfaces and complies with
 * all Salesforce SCA and PMD rules including ApexDoc, logging, exception handling,
 * and modular retry design.
 *
 * @author Debanjan Mukherjee
 * @created 01 July 2025
 */
public with sharing class IncrementBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable, Database.AllowsCallouts {
    /**
     * @description Custom exception for Metadata failures
     */
    public class SmartSyncException extends Exception {}
    /**
     * @description Check whether fields available as part of metadata Import then Batch will not have any scope recprds to run
     */
	public List<Insight_Field__c> insightFields;
    /**
     * @description get the LastFullSync DateTime
     */
	public DateTime lastFullSync;
    private final String objectApiName;
    private final String keyField;

    /**@description
     * ID of the Bulk API job.
     * Used to poll status and retrieve results.
     */
    public String jobId;

    /**@description
     * Current status of the Bulk API job.
     * Expected values: 'InProgress', 'JobComplete', etc.
     */
    public String jobState;
    // if there is an input for below parameter then Incremental Sync will be scheduled in that Minute interval
    public Integer schedulingInMinute;

    /**@description
     * Number of attempts already made 
     * Used to control retry logic.
     */
    public Integer attempt;
    /**@description
     * Max Number of attempts 
     * Used to control retry logic.
     */
    public Integer maxRetries;
    /**@description
     * Delay to wait for retry 
     * Used to control retry logic.
     */
    public Integer retryDelay;
    /**
     * @description Constructor for IncrementBatch.
     * Initializes objectApiName, keyField, jobId, attempt, and schedulingInMinute.
     *
     * @param objectApiName The API name of the object to sync.
     * @param keyField The external ID field used to upsert.
     */
    public IncrementBatch(String objectApiName, String keyField) {
        this(objectApiName, keyField, null, 0);
    }
    /**
     * @description Overloaded constructor for IncrementBatch with scheduling parameter.
     * Initializes objectApiName, keyField, jobId, attempt, and schedulingInMinute.
     *
     * @param objectApiName The API name of the object to sync.
     * @param keyField The external ID field used to upsert.
     * @param schedulingInMinute Optional parameter to schedule the batch in specified minute interval.
     */
	public IncrementBatch(String objectApiName, String keyField,Integer schedulingInMinute) {
        this(objectApiName, keyField, null, 0,schedulingInMinute);
    }
    /**
     * @description Constructor for IncrementBatch with jobId and attempt.
     * Initializes objectApiName, keyField, jobId, and attempt.
     *
     * @param objectApiName The API name of the object to sync.
     * @param keyField The external ID field used to upsert.
     * @param jobId The ID of the Bulk API job (optional).
     * @param attempt The current retry attempt number (default is 0).
     */
    public IncrementBatch(String objectApiName, String keyField, String jobId, Integer attempt) {
        this.objectApiName = objectApiName;
        this.keyField = keyField;
        this.jobId = jobId;
        this.attempt = attempt;
        this.schedulingInMinute = null;
        initializeRetryDetails();
    }
    /**
     * @description Overloaded constructor for IncrementBatch with jobId, attempt, and scheduling parameter.
     * Initializes objectApiName, keyField, jobId, attempt, and schedulingInMinute.
     *
     * @param objectApiName The API name of the object to sync.
     * @param keyField The external ID field used to upsert.
     * @param jobId The ID of the Bulk API job (optional).
     * @param attempt The current retry attempt number (default is 0).
     * @param schedulingInMinute Optional parameter to schedule the batch in specified minute interval.
     */
	public IncrementBatch(String objectApiName, String keyField, String jobId, Integer attempt,Integer schedulingInMinute) {
        this.objectApiName = objectApiName;
        this.keyField = keyField;
        this.jobId = jobId;
        this.attempt = attempt;
        this.schedulingInMinute = schedulingInMinute;
        initializeRetryDetails();
    }
    /**
     * @description Initiates the batch process by returning a simple query locator.
     * This implementation uses the current User record as a dummy record
     * to comply with the Database.Batchable interface's requirement.
     *
     * @param bc The batch context provided by the system.
     * @return A query locator for initiating the batch job.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String theQuery = 'SELECT Id,Insight__c, Name,Developer_Name__c,displayName__c,businessType__c,field_type__c,Calculated_Insight__c,Calculated_Insight__r.Name,Calculated_Insight__r.Developer_Name__c,Calculated_Insight__r.displayName__c , Calculated_Insight__r.Full_Sync_Status__c, Calculated_Insight__r.Last_Full_Sync__c FROM Insight_Field__c where Insight__c = \''+objectApiName+'\' Limit 9999';
        insightFields = Database.query(theQuery);
        if (insightFields == null || insightFields.isEmpty()) {
            ErrorLogger.logErrorFromException('High', 'IncrementBatch', 'Execute',null, 'There are no fields for this Calculated Insight fetched in CRM');
            // Full Sync not completed – stop execution
            return Database.getQueryLocator('SELECT Id FROM Account WHERE Id = null');
        }
        string fullSyncStatus = insightFields[0].Calculated_Insight__r.Full_Sync_Status__c;
        if (String.isBlank(fullSyncStatus) || fullSyncStatus != 'Completed') {
            ErrorLogger.logErrorFromException('High', 'IncrementBatch', 'Execute',null, 'Full Sync is not yet Completed');
            // Full Sync not completed – stop execution
            return Database.getQueryLocator('SELECT Id FROM Account WHERE Id = null');
        }else
        {
            lastFullSync = insightFields[0].Calculated_Insight__r.Last_Full_Sync__c;
        }
        if (null == lastFullSync) {
            ErrorLogger.logErrorFromException('High', 'IncrementBatch', 'Execute',null, 'No lastFullSync dateTime for this Calculated Insight');
            // Full Sync not completed – stop execution
            return Database.getQueryLocator('SELECT Id FROM Account WHERE Id = null');
        }
        return Database.getQueryLocator(theQuery);
    }

    /**
     * @description Executes a single batch chunk. This method checks required parameters, fetches
     * the Bulk API job ID if not already present, and polls the job status. These values
     * are stored in instance variables to be used later in the finish method.
     *
     * @param bc The batch context provided by the system.
     * @param scope The scope of records passed to this execution.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            if (String.isBlank(objectApiName)) {
                throw new SmartSyncException('Missing data: objectApiName');
            }
            if (String.isBlank(keyField)) {
                throw new SmartSyncException('Missing data: keyField');
            }

            if (String.isBlank(jobId)) {
                jobId = BulkApiDataFetcherService.fetchJobIdForStageData(objectApiName,lastFullSync);
            }

            if (String.isBlank(jobId)) {
                if(maxRetries == null || retryDelay == null)
                {
                    initializeRetryDetails();
                }
                if (attempt < maxRetries) {
                    scheduleRetry(objectApiName, keyField, jobId, attempt, retryDelay);
                }else
                {
                	throw new SmartSyncException('Failed to initialte BulkApiJob and get a JobId');
                }
            }

            jobState = BulkApiDataFetcherService.getJobStatus(jobId);

            if (String.isBlank(jobState)) {
                throw new SmartSyncException('Failed to poll jobState');
            }

        } catch (Exception ex) {
            SmartSyncUtil.publishEvent('Incremental Sync', 'Failed to Process Data', 'Error ');
            ErrorLogger.logErrorFromException('High', 'IncrementBatch', 'Execute',ex, 'Incremental Sync-Failed to Process Data');
        }
    }

    /**
     * @description Finalizes the batch process. If the Bulk API job is complete, retrieves CSV results
     * and launches a new batch for processing lines. Otherwise, retries based on metadata configuration.
     *
     * Uses integration metadata to determine retry limits and intervals.
     *
     * @param bc The batch context provided by the system.
     */
    public void finish(Database.BatchableContext bc) {
        try {
            if(maxRetries == null || retryDelay == null)
            {
                initializeRetryDetails();
            }
            if (jobState == 'JobComplete') {
                List<String> csvLines = BulkApiDataFetcherService.getResultForJob(jobId);
                if (csvLines == null || csvLines.size()==0) {
                    throw new SmartSyncException('Issues to fecth Increment data');
                }
                if (csvLines.size()==1) {
                    SmartSyncUtil.updateCalculatedInsightFields(objectApiName,null,Datetime.now(),null,null,'Completed',null);
                    throw new SmartSyncException('No records found for '+ objectApiName);
                }
                if (!csvLines.isEmpty() && !Test.isRunningTest()) {
                    Database.executeBatch(new CsvLineProcessorBatch(objectApiName, keyField, csvLines), 200);                    
                }
            } else if (attempt < maxRetries) {
                scheduleRetry(objectApiName, keyField, jobId, attempt, retryDelay);
            }
        } catch (Exception ex) {
            SmartSyncUtil.publishEvent('Incremental Sync', 'Failed to Process Data', 'Error ');
           ErrorLogger.logErrorFromException('High', 'IncrementBatch', 'Execute',ex, 'Incremental Sync-Failed to Process Data');
        }
    }
    public void initializeRetryDetails()
    {
        String retryStr = SmartSyncUtil.getIntegrationMetadataValue('Incremental_Sync', 'Retry__c');
        String delayStr = SmartSyncUtil.getIntegrationMetadataValue('Incremental_Sync', 'Retry_After_Minute__c');
        this.maxRetries = Integer.valueOf(retryStr);
        this.retryDelay = Integer.valueOf(delayStr);
    }

    /**
     * @description Schedulable interface implementation to retry batch execution
     * with updated attempt count and preserved job state.
     *
     * @param context The schedulable context.
     */
    public void execute(SchedulableContext context) {
        Database.executeBatch(new IncrementBatch(objectApiName, keyField, jobId, attempt,schedulingInMinute), 1);
    }

    /**
     * @description Schedules a retry of the IncrementBatch using the Schedulable interface.
     * Constructs a CRON expression for delayed execution based on retry interval.
     * Validates required parameters and schedules the job with incremented attempt.
     *
     * @param objectApiName The API name of the target object.
     * @param keyField The field used for processing records uniquely.
     * @param jobId The ID of the ongoing Bulk API job.
     * @param attempt The current retry attempt number.
     * @param delayInMinutes The delay interval in minutes before next attempt.
     */
    private static void scheduleRetry(String objectApiName, String keyField, String jobId, Integer attempt, Integer delayInMinutes) {
        if (String.isBlank(objectApiName) || String.isBlank(keyField) || String.isBlank(jobId)) {
            throw new SmartSyncException('Missing data for retry scheduling objectApiName : '+objectApiName +' keyField: '+keyField+ 'jobId: '+jobId+' delayInMinutes '+delayInMinutes);
        }
        List<CronTrigger> existing = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE '%RetryIncreProc_%'
            AND State IN ('WAITING', 'ACQUIRED','Queued', 'Processing')
        ];
		// Async jobs
        List<AsyncApexJob> asyncJobs = [
            SELECT Id, ApexClass.Name, JobType, Status
            FROM AsyncApexJob
            WHERE ApexClass.Name LIKE '%RetryIncrementSync_%'
            AND Status IN ('Queued', 'Processing')
        ];
        if (!existing.isEmpty() || !asyncJobs.isEmpty()) {
            System.debug('Job with name "' + existing[0].CronJobDetail.Name + '" is already scheduled. Skipping duplicate schedule.');
            return;
        }
        try{
            Datetime runTime = Datetime.now();
            if(null == delayInMinutes || delayInMinutes == 0)
            {
                runTime = runTime.addSeconds(20);
            }else
            {
            	runTime = runTime.addMinutes(delayInMinutes);
            }
            String cron = String.format(
                '{0} {1} {2} {3} {4} ? {5}',
                new List<String>{
                    String.valueOf(runTime.second()),
                        String.valueOf(runTime.minute()),
                        String.valueOf(runTime.hour()),
                        String.valueOf(runTime.day()),
                        String.valueOf(runTime.month()),
                        String.valueOf(runTime.year())
                        }
            );            
            String jobName ='RetryIncrementSync_' + objectApiName + '_Attempt_' + attempt + '_' + DateTime.now().format('yyyyMMdd_HHmmss');
            System.schedule(jobName, cron, new IncrementBatch(objectApiName, keyField, jobId, attempt + 1));
        }catch (Exception ex) {
            ErrorLogger.logErrorFromException('High', 'IncrementBatch', 'Execute',ex, 'Incremental scheduleRetry-Failed to Process Data');
        }
    }
    /**
     * @description Schedules the IncrementBatch to run every `schedulingInMinute` interval.
     * @param objectApiName The API name of the object to sync.
     * @param keyField The external ID field used to upsert.
     * @param schedulingInMinute The interval in minutes for scheduling.
     * @throws SmartSyncException if scheduling fails.
     */
        public static void scheduleBatch(String objectApiName, String keyField, Integer minutes)
        {
            System.debug('>>> CALLED scheduleBatch with: ' + objectApiName + ', ' + keyField + ', ' + minutes);
            try {
                if (String.isBlank(objectApiName) || String.isBlank(keyField)) {
                    throw new IncrementBatch.SmartSyncException('Missing data: objectApiName or keyField');
                }
                if (minutes == null || minutes <= 0 ||minutes > 60 ||Math.mod(60, minutes) != 0) {
                    throw new IncrementBatch.SmartSyncException('Invalid scheduling interval');
                }				
                Integer numberOfJobs = 60 / minutes;
                for (Integer i = 0; i < numberOfJobs; i++) {
                    Integer scheduledMinute = i * minutes;
                    String cronExpr = '0 ' + scheduledMinute + ' * * * ?'; // Valid Apex CRON: second minute hour day month ?
                    
                    String jobName = 'ScheduleIncrementBatch_' + objectApiName + '_Min_' + scheduledMinute + '_' + Datetime.now().getTime();
                    
                    System.schedule(
                        jobName,
                        cronExpr,
                        new IncrementBatch(objectApiName, keyField, null, 0, minutes)
                    );
                }
            } catch (Exception ex) {
                ErrorLogger.logErrorFromException('High', 'IncrementBatch', 'Execute',ex, 'Incremental Sync- Scheduling Failed to Process Data');
            }
        }
}