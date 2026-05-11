/**
 * @name        CIBatchProcessor
 * @description Batch job to fetch Calculated Insight data from Data Cloud with retry and callout threshold logic.
 *              Uses metadata-driven configuration and logs sync completion/error to Calculated_Insight__c.
 *              maxNumberOfCalls is intended for testing purposes only to prevent infinite retry loops.
 * @implements  Database.Batchable, Database.AllowsCallouts, Database.Stateful
 * @author      Debanjan Mukherjee
 * @created     2025-06-22
 */
public with sharing class CIBatchProcessor implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private final String cioName;
    private final Boolean useStub;
    private Integer currOffset;
    private Integer maxNumberOfCalls;
    private Integer currRetryCount;
    private Integer executionCount;

    @testVisible private Integer metadataOffset;
    @testVisible private String processingStatus;
    @testVisible private Boolean nearCalloutLimit = false;
    @testVisible private String processingError;
    /**
     * @description Flag to indicate if the batch is near callout limit.
     *              If true, it will not process further and will schedule for next day retry.
     */
	@testVisible public static boolean forceException = false;
    /**
     * @description Custom exception for Data Service failures
     */
    public class DataServiceException extends Exception {}
    /**
     * @description Constructor for CIBatchProcessor.
     * Initializes the batch with CI name, stub mode, current offset, max calls, retry count, and execution count.
     * @param cioName The Developer Name of the Calculated Insight Object (without __c suffix).
     * @param useStub Boolean to indicate if stub mode should be used.
     * @param currOffset Current offset for pagination.
     * @param maxNumberOfCalls Maximum number of calls to make (for testing purposes).
     * @param currRetryCount Current retry count.
     * @param executionCount Current execution count.
     */
    public CIBatchProcessor(String cioName, Boolean useStub, Integer currOffset, Integer maxNumberOfCalls, Integer currRetryCount, Integer executionCount) {
        this.cioName = cioName;
        this.useStub = useStub;
        this.currOffset = currOffset != null ? currOffset : 0;
        this.maxNumberOfCalls = maxNumberOfCalls;
        this.currRetryCount = currRetryCount != null ? currRetryCount : 0;
        this.executionCount = executionCount != null ? executionCount : 1;
         if (Test.isRunningTest()) {
            this.metadataOffset = 100; // safe fallback for tests
        }
    }
    /**
     * @description Starts the batch process and initializes metadata offset from SmartSync_Integration_Endpoint__mdt.
     * @param context Batchable context
     * @return QueryLocator for the current user
     * @note This method is required by the Database.Batchable interface.
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        try {
            SmartSync_Integration_Endpoint__mdt meta = [
                SELECT limit__c FROM SmartSync_Integration_Endpoint__mdt
                WHERE DeveloperName = 'Calculated_Insight'
                LIMIT 1
            ];
            metadataOffset = meta.limit__c != null ? meta.limit__c.intValue() : 100;
        } catch (Exception ex) {
            metadataOffset = 100;
        }
        return Database.getQueryLocator([
            SELECT Id FROM User WHERE Id = :UserInfo.getUserId()
        ]);
    }
    /**
     * @description Executes the batch logic to fetch data from the selected Calculated Insight.
     *              Checks callout limits and handles retries based on metadata configuration.
     * @param context Batchable context
     * @param scope List of SObjects (not used, but required by Database.Batchable interface)
     * @note This method is called for each batch execution.
     */
    public void execute(Database.BatchableContext context, List<SObject> scope) {
        try {
            Integer calloutThreshold = fetchMetadataValue('Callout_Threshold', 95);
            Integer used = Limits.getCallouts();
            Integer max = Limits.getLimitCallouts();
            Integer percentUsed = (used * 100) / max;

            if (percentUsed >= calloutThreshold) {
                nearCalloutLimit = true;
                throw new DataServiceException('Failed to Full Sync.Api Limit reached. Will Automatically start processing tomorrow');
            }
            processingStatus = getDataOfSelectedCI(cioName, useStub, currOffset);
            if(Test.isRunningTest() && forceException)
            {
                throw new DataServiceException('Failed to Full Sync.Api Limit reached. Will Automatically start processing tomorrow');
            }
        } catch (Exception ex) {
            Integer retryInterval = fetchMetadataValue('Data_Processing_Retry_Interval', 20);
            Integer maxRetries = fetchMetadataValue('Max_Retries', 5);
			processingError = 'Retrying after '+retryInterval+' CurrRetryCount: ' + CurrRetryCount;
            if (currRetryCount < maxRetries) {
                scheduleRetryAfterMinutes(retryInterval);
                ErrorLogger.logErrorFromException('Medium', 'CIBatchProcessor', 'Retry',ex, processingError);
                SmartSyncUtil.publishEvent(
                    'Full Sync',
                    processingError,
                    'Error - Retrying'
                );
            }else
            {
                ErrorLogger.logErrorFromException('High', 'CIBatchProcessor', 'Execute',ex, 'Failed to retrieve data from Data cloud - All retry failed');
                SmartSyncUtil.publishEvent(
                    'Full Sync',
                    'Failed to retrieve data from Data cloud - All retry failed',
                    'Error'
                );
            }
        }
    }
    /**
     * @description Handles post-execution logic, including retry scheduling and error handling.
     *              Checks if the batch is done or if it has reached the maximum number of calls.
     *              If near callout limit, schedules for next day retry.
     * @param context Batchable context
     * @note This method is called after all batches are processed.
     */
    public void finish(Database.BatchableContext context) {
        Boolean isDone = 'true'.equalsIgnoreCase(processingStatus);
        Boolean maxReached = maxNumberOfCalls != null && maxNumberOfCalls > 0 && executionCount >= maxNumberOfCalls;
		Boolean hasFailed = false;
        String errorMessage = '';
        if (maxReached) {
            isDone = true;
        }

        if (!isDone && !maxReached && !nearCalloutLimit && processingError == null) {
            Integer nextOffset = currOffset + metadataOffset;
            Integer nextRetryCount = currRetryCount + 1;
            Integer nextExecutionCount = executionCount + 1;

            Database.executeBatch(
                new CIBatchProcessor(cioName, useStub, nextOffset, maxNumberOfCalls, nextRetryCount, nextExecutionCount), 1
            );
        } else if (nearCalloutLimit && !maxReached) {

            scheduleNextDayRetry(currOffset + metadataOffset, currRetryCount + 1, executionCount + 1);
        }
        try {
            if (!Test.isRunningTest()) {
                AsyncApexJob job = [
                    SELECT Id, Status, NumberOfErrors
                    FROM AsyncApexJob
                    WHERE Id = :context.getJobId()
                    LIMIT 1
                ];
                hasFailed = (job.NumberOfErrors > 0);
            }
            if (hasFailed || (Test.isRunningTest() && forceException)) {
            	throw new DataServiceException('Full Sync CIBatchProcessor Data retrieval failed');
            }else
            {
                SmartSyncUtil.updateCalculatedInsightFields(cioName,Datetime.now(),null,null,'Completed',null,null);
                SmartSyncUtil.publishEvent(
                    'Full Sync',
                    '',
                    'Success'
                );
            }
        } catch (Exception ex) {
            hasFailed = true;
            SmartSyncUtil.updateCalculatedInsightFields(cioName,Datetime.now(),null,null,'Failed',null,null);
            SmartSyncUtil.publishEvent(
                    'Full Sync',
                    'Full Sync CIBatchProcessor Data retrieval failed',
                    'Error'
                );
            ErrorLogger.logErrorFromException('High', 'CIBatchProcessor', 'Finish',ex, 'Failed to retrieve data from Data cloud');
        }
    }

    /**
     * @description Fetches value from Generic_Key_Value__mdt
     * @param key The metadata key
     * @param fallback Fallback integer value
     * @return Integer value from metadata or fallback
     */
    private Integer fetchMetadataValue(String key, Integer fallback) {
        try {
            Generic_Key_Value__mdt valueMdt = [
                SELECT Value__c FROM Generic_Key_Value__mdt
                WHERE Key__c = :key LIMIT 1
            ];
            return Integer.valueOf(valueMdt.Value__c);
        } catch (Exception ex) {
            System.debug('Metadata for key ' + key + ' not found. Using fallback: ' + fallback);
            return fallback;
        }
    }
    /**
     * @description Schedules this batch for retry after specified minutes
     * @param minutes Number of minutes to wait before retrying
     */
    private void scheduleRetryAfterMinutes(Integer minutes) {
        Datetime futureTime = Datetime.now().addMinutes(minutes);
        String cron = getCronExpressionForDatetime(futureTime);
        String jobName = 'CI_ErrorRetry_' + String.valueOf(Datetime.now().getTime());

        CIBatchScheduler scheduler = new CIBatchScheduler(cioName, useStub, currOffset, maxNumberOfCalls, currRetryCount + 1, executionCount + 1);
        System.schedule(jobName, cron, scheduler);
    }
    /**
     * @description Schedules the next day retry for the batch
     * @param nextOffset The offset for the next execution
     * @param retryCount The current retry count
     * @param nextExecutionCount The next execution count
     */
    private void scheduleNextDayRetry(Integer nextOffset, Integer retryCount, Integer nextExecutionCount) {
        String cronExpr = getCronExpressionForDatetime(Datetime.now().addDays(1));
        String jobName = 'Retry_CI_' + String.valueOf(Datetime.now().getTime());

        CIBatchScheduler scheduler = new CIBatchScheduler(cioName, useStub, nextOffset, maxNumberOfCalls, retryCount, nextExecutionCount);
        System.schedule(jobName, cronExpr, scheduler);
    }
    /**
     * @description Builds cron expression for future scheduling
     * @param dt Datetime object to convert to cron expression
     * @return Cron expression string
     */
    private static String getCronExpressionForDatetime(Datetime dt) {
        return String.format(
            '{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(dt.second()),
                String.valueOf(dt.minute()),
                String.valueOf(dt.hour()),
                String.valueOf(dt.day()),
                String.valueOf(dt.month()),
                String.valueOf(dt.year())
            }
        );
    }
    /**
    * @name        CIBatchScheduler
    * @description Schedulable class to execute CIBatchProcessor with specific parameters.
    *              This class is used to schedule the batch job for retry or next execution.
    * @implements  Schedulable
    * @author      Debanjan Mukherjee
    * @created     2025-06-22
    */
    public class CIBatchScheduler implements Schedulable {
        private final String cioName;
        private final Boolean useStub;
        private final Integer offset;
        private final Integer maxNumberOfCalls;
        private final Integer retryCount;
        private final Integer executionCount;
        /**
         * @description Constructor for CIBatchScheduler.
         * Initializes the scheduler with CI name, stub mode, offset, max calls, retry count, and execution count.
         * @param cioName The Developer Name of the Calculated Insight Object (without __c suffix).
         * @param useStub Boolean to indicate if stub mode should be used.
         * @param offset Current offset for pagination.
         * @param maxNumberOfCalls Maximum number of calls to make (for testing purposes).
         * @param retryCount Current retry count.
         * @param executionCount Current execution count.
         */
        public CIBatchScheduler(String cioName, Boolean useStub, Integer offset, Integer maxNumberOfCalls, Integer retryCount, Integer executionCount) {
            this.cioName = cioName;
            this.useStub = useStub;
            this.offset = offset;
            this.maxNumberOfCalls = maxNumberOfCalls;
            this.retryCount = retryCount;
            this.executionCount = executionCount;
        }
        /**
         * @description Executes the batch job with the provided parameters.
         *              This method is called by the scheduler to start the batch process.
         * @param context Schedulable context
         */
        public void execute(SchedulableContext context) {
            Database.executeBatch(
                new CIBatchProcessor(cioName, useStub, offset, maxNumberOfCalls, retryCount, executionCount), 1
            );
        }
    }
    /** * @description Fetches data from the selected Calculated Insight and creates records.
    *              Uses stub mode if specified.
    * @param ciName The Developer Name of the Calculated Insight Object (without __c suffix).
    * @param useStub Boolean to indicate if stub mode should be used.
    * @param currOffset Current offset for pagination.
    * @return String indicating the status of the operation.
    * @throws DataServiceException if initialization fails or data retrieval fails.
    */
    public static string getDataOfSelectedCI(String ciName,boolean useStub,integer currOffset) {
        try {
            CiDataHelper.enableStubMode(useStub);
            string isDone = CiDataHelper.createRecordsFromInsightFields(ciName,currOffset);
            System.debug(isDone);
            return isDone;
        } catch (Exception ex) {
            throw new DataServiceException('Failed to initialize CI structure: ' + ex.getMessage());
        }
    }
}