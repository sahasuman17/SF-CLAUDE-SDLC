/**
 * @description BulkStageDeleterBatch performs external deletion of Smart_Sync_Stage__c records
 * using Salesforce Bulk API 2.0 based on a list of stage record Ids.
 * @name BulkStageDeleterBatch
 * It is designed to be PMD and Salesforce Code Analyzer (SCA) compliant.
 * Error handling includes SmartSync event publishing and async error logging.
 *
 * Author: Debanjan Mukherjee
 * Created Date: 01 Jul 2024
 */
public with sharing class BulkStageDeleterBatch implements Database.Batchable<Id>, Database.Stateful, Database.AllowsCallouts {
    /**
     * @description Custom exception for Metadata failures
     */
    public class SmartSyncException extends Exception {}

    private final List<Id> stageRecordIds;
    private Integer retryCount = 0;
    private Integer maxRetries;
    private Integer retryDelay;

    private static final String SYNC_SOURCE = 'Incremental_Sync';

    /**
     * Constructor for the batch class.
     *@description Initializes the batch with a list of Smart_Sync_Stage__c record Ids to delete.
     * If the input list is null, it initializes with an empty list.
     * @param successStageRecordIds The list of Smart_Sync_Stage__c record Ids to delete.
     */
    public BulkStageDeleterBatch(List<Id> successStageRecordIds) {
        this.stageRecordIds = successStageRecordIds != null ? successStageRecordIds : new List<Id>();
    }
    /**
     * Loads retry metadata from Integration_Metadata__mdt.
     * @description Fetches the max retries and retry delay from custom metadata.
     * Throws SmartSyncException if metadata is missing or incorrect.
     */
    private void loadRetryMetadata() {
        try {
            String retryStr = SmartSyncUtil.getIntegrationMetadataValue(SYNC_SOURCE, 'Retry__c');
            String delayStr = SmartSyncUtil.getIntegrationMetadataValue(SYNC_SOURCE, 'Retry_After_Minute__c');

            if (String.isBlank(retryStr) || String.isBlank(delayStr)) {
                throw new SmartSyncException('Missing Retry__c or Retry_After_Minute__c in Integration_Metadata__mdt');
            }

            maxRetries = Integer.valueOf(retryStr);
            retryDelay = Integer.valueOf(delayStr);
        } catch (Exception ex) {
            throw new SmartSyncException('Incorrect data in Incremental_Sync metadata record');
        }
    }
    /**
     * Starts the batch process.
     * @description Loads retry metadata and returns the list of stage record Ids to process.
     * If metadata loading fails, it logs an error and returns an empty list.
     * @param context The batchable context.
     * @return Iterable of Ids to process in the batch.
     */
    public Iterable<Id> start(Database.BatchableContext context) {
        try {
            loadRetryMetadata();
            return stageRecordIds;
        } catch (Exception ex) {
            SmartSyncUtil.publishEvent('Incremental Sync', 'Failed to Process Data', 'Error');
            ErrorLogger.logHighErrorAsync(ex, 'Incremental Sync - Failed to Load Retry Metadata');
            return new List<Id>();
        }
    }
    /**
     * Executes the batch for each scope of Smart_Sync_Stage__c record Ids.
     * @description Deletes the records using Bulk API 2.0 and handles retries on failure.
     * If the scope is null or empty, it throws an exception.
     * @param context The batchable context.
     * @param scope The list of Smart_Sync_Stage__c record Ids to delete.
     */
    public void execute(Database.BatchableContext context, List<Id> scope) {
        try {
            if (scope == null || scope.isEmpty()) {
                throw new SmartSyncException('Missing scope records in execute()');
            }

            List<String> idsToDelete = new List<String>();
            for (Id recordId : scope) {
                idsToDelete.add(String.valueOf(recordId));
            }

            Boolean isSuccess = deleteViaBulkApi(idsToDelete);

            if (!isSuccess && retryCount < maxRetries) {
                retryCount++;
                // $&
                execute(context, scope);
            } else if (!isSuccess) {
                throw new SmartSyncException('Bulk deletion failed after max retries for scope: ' + idsToDelete);
            }
        } catch (Exception ex) {
            SmartSyncUtil.publishEvent('Incremental Sync', 'Failed to Process Data', 'Error');
            ErrorLogger.logErrorFromException('High', 'BulkStageDeleterBatch', 'Finish',ex, 'Incremental Sync - Failed in execute()');
        }
    }
    /**
     * Finalizes the batch process.
     * @description Publishes a success event if the batch completes successfully.
     * If an error occurs, it logs the error and publishes an error event.
     * @param context The batchable context.
     */
    public void finish(Database.BatchableContext context) {
        try {            
            SmartSyncUtil.publishEvent('Incremental Sync', '', 'Success');
        } catch (Exception ex) {
            SmartSyncUtil.publishEvent('Incremental Sync', 'Failed to Process Data', 'Error');
            ErrorLogger.logHighErrorAsync(ex, 'Incremental Sync - Failed in finish()');
        }
    }
    /**
     * Deletes records using Salesforce Bulk API 2.0.
     * @description This method creates a Bulk API job to delete Smart_Sync_Stage__c records by Id.
     * It handles job creation, CSV upload, and job completion.
     * @param recordIds The list of Smart_Sync_Stage__c record Ids to delete.
     * @return True if deletion was successful, false otherwise.
     */
    @TestVisible
    private static Boolean deleteViaBulkApi(List<String> recordIds) {
        Http http = new Http();
        try {
            DataCloudAuthService.TokenResponse token = DataCloudAuthService.authOnlyCRM();
            if (token == null || String.isBlank(token.access_token) || String.isBlank(token.instance_url)) {
                throw new SmartSyncException('Access token is blank or null');
            }

            String endpointSuffix = SmartSyncUtil.getIntegrationMetadataValue(SYNC_SOURCE, 'Synch_Endpoint__c');
            if (String.isBlank(endpointSuffix)) {
                throw new SmartSyncException('Missing endpoint URL for Incremental_Sync.Synch_Endpoint__c');
            }
			endpointSuffix = endpointSuffix.replace('query','ingest');
            String fullEndpoint = token.instance_url + endpointSuffix;

            Map<String, Object> jobPayload = new Map<String, Object>{
                'object' => 'Smart_Sync_Stage__c',
                'operation' => 'delete',
                'contentType' => 'CSV',
                'lineEnding' => 'LF'
            };

            HttpRequest jobReq = new HttpRequest();
            jobReq.setEndpoint(fullEndpoint);
            jobReq.setMethod('POST');
            jobReq.setHeader('Authorization', 'Bearer ' + token.access_token);
            jobReq.setHeader('Content-Type', 'application/json');
            jobReq.setBody(JSON.serialize(jobPayload));

            HttpResponse jobRes = http.send(jobReq);
            if (jobRes.getStatusCode() != 200 && jobRes.getStatusCode() != 201) {
                throw new SmartSyncException('Job creation failed: ' + jobRes.getBody());
            }

            Map<String, Object> jobResponse = (Map<String, Object>) JSON.deserializeUntyped(jobRes.getBody());
            String jobId = (String) jobResponse.get('id');

            String csvBody = 'Id\n' + String.join(recordIds, '\n');

            HttpRequest uploadReq = new HttpRequest();
            uploadReq.setEndpoint(fullEndpoint + '/' + jobId + '/batches');
            uploadReq.setMethod('PUT');
            uploadReq.setHeader('Authorization', 'Bearer ' + token.access_token);
            uploadReq.setHeader('Content-Type', 'text/csv');
            uploadReq.setBody(csvBody);

            HttpResponse uploadRes = http.send(uploadReq);
            if (uploadRes.getStatusCode() != 201) {
                throw new SmartSyncException('CSV upload failed: ' + uploadRes.getBody());
            }

            HttpRequest closeReq = new HttpRequest();
            closeReq.setEndpoint(fullEndpoint + '/' + jobId);
            closeReq.setMethod('PATCH');
            closeReq.setHeader('Authorization', 'Bearer ' + token.access_token);
            closeReq.setHeader('Content-Type', 'application/json');
            closeReq.setBody(JSON.serialize(new Map<String, Object>{ 'state' => 'UploadComplete' }));

            HttpResponse closeRes = http.send(closeReq);
            if (closeRes.getStatusCode() != 200) {
                throw new SmartSyncException('Job close failed: ' + closeRes.getBody());
            }

            return true;
        } catch (Exception ex) {
            // $&
            return false;
        }
    }
}