/**
 * @name        CreateCustomObjectBatch
 * @description Create the custom object
 * @author      Debanjan Mukherjee
 * @created     2025-06-26
 */
global class CreateCustomObjectBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful  {

    private String objectName;
    private String objectAPI;
    private String objectPlural;
    private String permissionSetName;
    private String permissionSetLabel;
    private Boolean creationSuccess = false; // used to track success
    private String errMessage;
    /**
     * @description forced exception for to check failure handling
     */
	@testVisible public static boolean forceException = false;
    /**
     * @description Custom exception for Metadata failures
     */
    public class MetadataServiceException extends Exception {}
    /**
     * @description Default constructor
     * @param objectName Name of the custom object
     * @param objectAPI API name of the custom object (should end with __c)
     * @param objectPlural Plural label of the custom object
     * @param permissionSetName Name of the permission set to be created
     * @param permissionSetLabel Label of the permission set to be created
     */
    public CreateCustomObjectBatch(String objectName, String objectAPI, String objectPlural, String permissionSetName,String permissionSetLabel) {
        this.errMessage = '';
        this.objectName = objectName;
        if(objectAPI.endsWith('__c'))
        {
            this.objectAPI = objectAPI;
        }
        else
        {
            this.objectAPI = objectAPI+'__c';
        }
        this.objectPlural = objectPlural;
        this.permissionSetName = permissionSetName;
        this.permissionSetLabel = permissionSetLabel;
    }
    /**
     * @description Starts the batch process
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
     * @description Executes the batch logic to create the custom object
     * @param bc Batchable context
     * @param scope List of SObjects (not used, but required by Database.Batchable interface)
     * @note This method is called for each batch execution.
     */
    // Execute method - will try to create the custom object
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            MetaDataServiceHandler.createCustomObject(objectName, objectAPI, objectPlural);
        }catch(Exception ex)
        {
            errMessage = errMessage+ex.getMessage();
        }
    }
    /**
     * @description Handles post-execution logic, including permission set updates and error handling
     * @param bc Batchable context
     * @note This method is called after all batches are processed.
     */
    // Finish method - runs after the batch completes
    global void finish(Database.BatchableContext bc) {
        try
        {
        	PermissionSetUpdater.grantCrudAccessViaMetadata(objectAPI,permissionSetName,permissionSetLabel);
        }
        catch(Exception ex)
        {
            ErrorLogger.logErrorFromException('High', 'CreateCustomObjectBatch', 'Finish',ex, 'Issues on PermissionSetUpdater.grantCrudAccessViaMetadata');
        	SmartSyncUtil.publishEvent(
                    'Full Sync',
                    'Issues on PermissionSetUpdater.grantCrudAccessViaMetadata',
                	'Error'
                );
        }
        if(objectAPI.endsWith('__c'))
        {
            this.objectAPI = objectAPI.replace('__c','');
        }
        Database.executeBatch(new CIMetadataFieldBatchProcessor(objectAPI, permissionSetName, 0), 10);
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
            if(Test.isRunningTest() && forceException)
            {
                throw new MetadataServiceException('Forced exception from Apex Test');
            }
        } catch (Exception ex) {
            hasFailed = true;
            theException = ex;
        }
        if (hasFailed) {
            errMessage = 'Object creation failure'+objectAPI;
            ErrorLogger.logErrorFromException('High', 'CreateCustomObjectBatch', 'Finish',theException, errMessage);
        	SmartSyncUtil.publishEvent(
                    'Full Sync',
                    errMessage,
                	'Error'
                );
        }

    }

}