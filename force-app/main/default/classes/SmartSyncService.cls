/**
 * @name        SmartSyncService
 * @description Executes Data Cloud API calls by dynamically retrieving endpoint configuration from Custom Metadata records.
 *              Uses only fields that are populated, without throwing errors for missing metadata values.
 * @author      Debanjan Mukherjee
 * @created     20 Jun 2025
 */
public with sharing class SmartSyncService {
    /**
     * @description Custom exception for Metadata failures
     */
    public class MetadataServiceException extends Exception {}
    /**
     * @description Retrieves all metadata for Calculated Insights from the Data Cloud.
     * @return JSON response containing metadata for all Calculated Insights
     */
    public static string getAllCioMetadata() {
        return invokeDataCloudCall('Insight_Metadata');
    }
    /**
     * @description Retrieves all metadata for Calculated Insights from the Data Cloud.
     * @return JSON response containing metadata for all Calculated Insights
     */
    public static string getSpecificCioMetadata(string cioDevName) {
        return invokeDataCloudCall('Insight_Metadata',cioDevName);
    }
    /**
     * @description Retrieves metadata for a specific Calculated Insight Object (CIO) by its Developer Name.
     * @param cioDevName Developer Name of the Calculated Insight Object (without __c suffix)
     *@param key Optional key to use for ordering results
     * @param currOffset Optional offset for pagination, defaults to metadata configuration value if not provided
     * @return JSON response containing metadata for the specified CIO
     */
    public static string getDataOfCio(String cioDevName,String key,integer currOffset) {
        return invokeDataCloudCall('Calculated_Insight', cioDevName,key,currOffset);
    }
    /**
     * @description Generic executor to call Data Cloud endpoints using custom metadata and optional CIO name.
     * @param metadataDevName Developer Name of the metadata record (e.g., Insight_Metadata)
     * @param cioName Optional insight object to append to the endpoint (if applicable)
     * @param key Optional key to use for ordering results
     * @param currOffset Optional offset for pagination, defaults to metadata configuration value if not provided
     * @return JSON response from the Data Cloud API call
     * @throws MetadataServiceException if any error occurs during the callout
     */
    private static string invokeDataCloudCall(String metadataDevName, String cioName,String key,integer currOffset) {
        try
        {
            List<SmartSync_Integration_Endpoint__mdt> configList = [
                SELECT DeveloperName, Base_Url__c, Http_Method__c, Synch_Endpoint__c,limit__c
                FROM SmartSync_Integration_Endpoint__mdt
                WHERE DeveloperName IN ('Insight_Metadata', 'Calculated_Insight')
            ];
            SmartSync_Integration_Endpoint__mdt selectedConfig;
            for (SmartSync_Integration_Endpoint__mdt config : configList) {
                if (config.DeveloperName == metadataDevName) {
                    selectedConfig = config;
                    break;
                }
            }
            if (selectedConfig == null) {
                // $&
                return 'No configuration found for: ' + metadataDevName;
            }
            String httpMethod = String.isNotBlank(selectedConfig.Http_Method__c)
                ? selectedConfig.Http_Method__c
                : 'GET';
            String baseUrl = String.isNotBlank(selectedConfig.Base_Url__c)
                ? selectedConfig.Base_Url__c
                : '';
            String endpoint = '';
            if (String.isNotBlank(selectedConfig.Synch_Endpoint__c)) {
                endpoint = selectedConfig.Synch_Endpoint__c;
            }
            if (String.isNotBlank(cioName)) {
                endpoint = endpoint.endsWith('/')
                    ? endpoint + cioName
                    : endpoint + '/' + cioName;
            }
            String fullEndpoint = baseUrl + endpoint;
            
            integer intLimit;
            System.debug('--------->'+selectedConfig);
            System.debug('--------->'+selectedConfig.limit__c);
            if(NULL!=selectedConfig.limit__c)
            {
                intLimit = (Integer)selectedConfig.limit__c;
            }else
            {
                intLimit = 10;
            }
            if(String.isEmpty(key))
            {
                key = 'unified_id__c';
            }
            fullEndpoint = fullEndpoint+'?limit='+intLimit+'&offset='+currOffset+'&orderby='+key;
            System.debug('ssc '+fullEndpoint);
            HttpResponse res = DataCloudIntegrationUtil.getDataFromDataCloud(httpMethod, fullEndpoint, '');
            return res.getBody();
        }
        catch(Exception ex)
        {
            throw new MetadataServiceException('Field creation error: ' , ex);
        }
    }
    /**
     * @description Overloaded version for fixed endpoints without dynamic CIO name.
     * @param metadataDevName Developer name of the metadata configuration
    * @return JSON response from the Data Cloud API call
     */
    private static string invokeDataCloudCall(String metadataDevName) {
        return invokeDataCloudCall(metadataDevName,null,null,null);
    }
    /**
     * @description Overloaded version for fixed endpoints without dynamic CIO name.
     * @param metadataDevName Developer name of the metadata configuration
    * @return JSON response from the Data Cloud API call
     */
    private static string invokeDataCloudCall(String metadataDevName,string cioDevName) {
        return invokeDataCloudCall(metadataDevName,cioDevName,null,0);
    }
}