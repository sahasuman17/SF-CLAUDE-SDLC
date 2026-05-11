/**
 * @name        CISyncController
 * @description Controller for front End
 * @author      Debanjan Mukherjee
 * @created     2025-06-26
 */
public with sharing class CISyncController {
    @AuraEnabled(cacheable=true)
    /**
     * @description Custom exception for failures
     * @returns List of Calculated_Insight__c records
     */
    public static List<Calculated_Insight__c> getCalculatedInsights() {
        if (!Schema.sObjectType.Calculated_Insight__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to read Calculated Insight records.');
        }
        return [
            SELECT Id, Name, Developer_Name__c, displayName__c, latestProcessTime__c,
                   latestSuccessfulProcessTime__c, Data_Sync_Done__c, Last_Data_Sync__c,
                   Data_Process_Error__c, Data_Processing_Retry_Interval__c, Metadata_Sync_Done__c
            FROM Calculated_Insight__c
            ORDER BY displayName__c ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    /**
     * @description Custom exception for failures
     * @param ciName Developer Name of the Calculated Insight Object (without __c suffix)
     * @returns List of Insight_Field__c records associated with the specified Calculated Insight
     */
    public static List<Insight_Field__c> getInsightFields(String ciName) {
        if (!Schema.sObjectType.Insight_Field__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to read Insight Field records.');
        }
        return [
            SELECT Id, Name, Calculated_Insight__c, Developer_Name__c,
                   displayName__c, field_type__c,
                   Calculated_Insight__r.displayName__c,
                   Calculated_Insight__r.Developer_Name__c
            FROM Insight_Field__c
            WHERE Calculated_Insight__r.Developer_Name__c = :ciName
            ORDER BY displayName__c ASC
        ];
    }
    /**
     * @description Custom exception for failures
     * @note This method is used to initialize the metadata for Calculated Insights.
     *       It clears any existing Error_Log__c records and starts the CiMetadataInitBatch.
     */
    @AuraEnabled
    public static void initializeMetadata() {
        List<Error_Log__c> logs = [SELECT Id FROM Error_Log__c];
        if (!logs.isEmpty()) {
            delete logs;
        }
        Database.executeBatch(new CiMetadataInitBatch(), 1);
    }
    /**
     * @description Custom exception for failures
     * @note This method is used to initialize the metadata for Calculated Insights.
     *       It clears any existing Error_Log__c records and starts the CiMetadataInitBatch.
     */
    @AuraEnabled
    public static void initializeSpecificMetadata(String cioDevName) {
        Insight_Field__c[] lstCiFields = [SELECT Id,Calculated_Insight__c FROM Insight_Field__c where Insight__c=:cioDevName LIMIT 9999];
        if (!lstCiFields.isEmpty()) {
            delete lstCiFields;
        }
        Database.executeBatch(new SpecificCiMetadataInitBatch(cioDevName), 1);
    } 
    /**
     * @description Custom exception for failures
     * @param pollingAttempt Current polling attempt number
     * @note This method checks the status of the insight sync process.
     *       It returns 'Success', 'NoData', 'Error', or 'InProgress' based on the latest Error_Log__c record.
     */
    @AuraEnabled
    public static String getInsightSyncStatus(Integer pollingAttempt) {
        List<Error_Log__c> logs = [
            SELECT ErrorMessage__c
            FROM Error_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
 
        if (!logs.isEmpty()) {
            String msg = logs[0].ErrorMessage__c;
            System.debug('>>> Attempt ' + pollingAttempt + ' | ErrorMessage__c: ' + msg);

            if (msg != null && msg.toLowerCase().contains('success fetching')) {
                Integer ciCount = [SELECT COUNT() FROM Calculated_Insight__c];
                System.debug('>>> CI Count: ' + ciCount);
                return (ciCount > 0) ? 'Success' : 'NoData';
            } else if (msg != null && msg.toLowerCase().startsWith('error fetching')) {
                return 'Error';
            }
        }
        return 'InProgress';
    }
    /**
     * @description Custom exception for failures
     * @param ciDevName Developer Name of the Calculated Insight Object (without __c suffix)
     * @note This method is used to trigger a full sync of the Calculated Insight data.
     */
    @AuraEnabled
    public static void fullSync(String ciDevName) {
        boolean isSuccess = SmartSyncInitializer.getSelectedCI(ciDevName, 'SmartSyncConsole', 'SmartSyncConsole');
    }
    /**
     * @description Custom exception for failures
     * @param ciDevName Developer Name of the Calculated Insight Object (without __c suffix)
     * @param fieldDevName Developer Name of the Insight Field (without __c suffix)
     * @note This method is used to trigger an incremental sync of the Calculated Insight data.
     */
    @AuraEnabled
    public static void incrementalSync(String ciDevName, String fieldDevName) {        
        Database.executeBatch(new IncrementBatch(ciDevName, fieldDevName), 1);
    }
    /**
     * @description Custom exception for failures
     * @param ciDevName Developer Name of the Calculated Insight Object (without __c suffix)
     * @param fieldDevName Developer Name of the Insight Field (without __c suffix)
     * @param scheduleInMin Schedule interval in minutes
     */
    @AuraEnabled
    public static void incrementalSyncWithSchedule(String ciDevName, String fieldDevName, String scheduleInMin) {
        try {
            Integer schedMin = Integer.valueOf(scheduleInMin);
    
            if (schedMin <= 0) {
                throw new IllegalArgumentException('Schedule interval must be greater than zero');
            }
    
            // Use the existing scheduler method, which handles cron setup
            IncrementBatch.scheduleBatch(ciDevName, fieldDevName, schedMin);
            //System.schedule('IncrementScheduler', '0 0 * * * ?', new ParentHourlyJobScheduler(ciDevName, fieldDevName, schedMin));
        } catch (Exception ex) {
            ErrorLogger.logHighErrorAsync(ex, 'Custom Exception occurred and logged via script');
        }
    }

}