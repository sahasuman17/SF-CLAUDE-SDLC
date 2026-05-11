/**
 * @name        MetadataTestHelper
 * @description Test utility class to inject mock metadata values for Generic_Key_Value__mdt
 *              and SmartSync_Integration_Endpoint__mdt into SmartSyncUtil caches.
 *              Enables deterministic unit testing without actual Custom Metadata records.
 * @author      Debanjan Mukherjee
 * @createdDate 04 July 2025
 */
@isTest
public class MetadataTestHelper {
    /**
     * @description Injects a map of key-value pairs to mock Generic_Key_Value__mdt records.
     *              This populates SmartSyncUtil's internal keyValueCache.
     * @param keyValueMap A map where keys are Key__c values and values are Value__c.
     */
    public static void injectGenericKeyValues(Map<String, Generic_Key_Value__mdt> keyValueMap) {
        SmartSyncUtil.setGenericKeyValueMap(keyValueMap);
    }
    /**
     * @description Injects a single SmartSync_Integration_Endpoint__mdt record into the SmartSyncUtil cache.
     * @param devName DeveloperName of the metadata record (used as key in internal cache).
     * @param fields A map of field API names to values (e.g., 'Synch_Endpoint__c' → '/url').
     */
    public static void injectIntegrationEndpoint(String devName, Map<String, String> fields) {
        SmartSync_Integration_Endpoint__mdt record = new SmartSync_Integration_Endpoint__mdt();
        record.DeveloperName = devName;
        SObject sobj = record;
        for (String fieldName : fields.keySet()) {
            sobj.put(fieldName, fields.get(fieldName));
        }
        Map<String, SmartSync_Integration_Endpoint__mdt> endpointMap = new Map<String, SmartSync_Integration_Endpoint__mdt>{
            devName => (SmartSync_Integration_Endpoint__mdt)sobj
        };
        SmartSyncUtil.setIntegrationEndpointMap(endpointMap);
    }
    /**
     * @description Injects a single SmartSync_Integration_Endpoint__mdt record into the SmartSyncUtil cache.
     *              This is a convenience method for testing with a complete metadata record.
     * @param devName DeveloperName of the metadata record (used as key in internal cache).
     * @param meta The SmartSync_Integration_Endpoint__mdt record to inject.
     */
	public static void injectIntegrationEndpoint(String devName, SmartSync_Integration_Endpoint__mdt meta) {
        SmartSyncUtil.setIntegrationEndpointMap(new Map<String, SmartSync_Integration_Endpoint__mdt>{
            devName => meta
        });
    }
    /**
     * @description Resets SmartSyncUtil caches for key-value metadata and integration metadata.
     */
    public static void resetMetadata() {
        SmartSyncUtil.resetCaches();
    }
}