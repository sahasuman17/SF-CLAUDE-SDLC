/**
 * @name        CiDataHelper
 * @description Invokes CI data retrieval and processes dynamic JSON using untyped deserialization.
 *              Provides utility methods to extract typed attributes from JSON response from Data Cloud.
 * @author      Debanjan Mukherjee
 * @created     2025-06-22
 */
public with sharing class CiDataHelper {
    private static Boolean runStub = false;
    /**
     * @description forced exception for to check failure handling
     */
	public static String testJsonOverride;
    /**
     * @description use stub response while Apex Test
        * @param useStub Boolean to indicate if stub data should be used (for testing)
     */
    public static void enableStubMode(Boolean useStub) {
        runStub = useStub;
    }
    /**
     * @description Creates and inserts records from CI JSON response into corresponding custom object
    * @param cioDevName Developer Name of the Calculated Insight Object (without __c suffix)
    * @param currOffset Current offset for pagination
    * @return List of inserted records
    * @throws DataServiceException if initialization fails
     */
    public static string createRecordsFromInsightFields(String cioDevName,integer currOffset) {
        List<Insight_Field__c> fieldDefs = [
            SELECT Name, field_type__c,Calculated_Insight__r.Developer_Name__c,Calculated_Insight__r.Key__c FROM Insight_Field__c
            WHERE Calculated_Insight__r.Developer_Name__c = :cioDevName
        ];
        List<SObject> resultRecords = new List<SObject>();
        String responseJson;

        if (Test.isRunningTest() || runStub) {
            if (String.isNotBlank(testJsonOverride)) {
                responseJson = testJsonOverride;
            } else {
                StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'cioDataStub' LIMIT 1];
                responseJson = sr.Body.toString();
            }
        } else {
            if(!cioDevName.endsWith('__cio'))
            	responseJson = SmartSyncService.getDataOfCio(cioDevName + '__cio',fieldDefs[0].Calculated_Insight__r.Key__c,currOffset);
        }

        if (String.isBlank(responseJson)) {
            return 'No records available in the selected Calculated Insight';
        }
        Map<String, Object> fullJson = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        boolean isDone = (boolean)fullJson.get('done');
        if (!fullJson.containsKey('data')) {
            return 'No records available in the selected Calculated Insight';
        }
        List<Object> dataList = (List<Object>) fullJson.get('data');
        String objectApiName = cioDevName + '__c';
		Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(objectApiName);
        if (sobjectType == null) {           
            return 'No Calculated Insight available with this Name';
        }
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        for (Object entryObj : dataList) {
            if (entryObj instanceof Map<String, Object>) {
                Map<String, Object> entry = (Map<String, Object>) entryObj;
                SObject record = (SObject) Type.forName('', objectApiName).newInstance();

                for (Insight_Field__c field : fieldDefs) {
                    String fieldName = field.Name;
                    if (fieldMap.containsKey(fieldName)) {
                        Schema.SObjectField sFld = fieldMap.get(fieldName);
                        if (sFld.getDescribe().isAccessible() && sFld.getDescribe().isCreateable()) {
                            if (entry.containsKey(fieldName) && fieldName != 'Id') {
                                Schema.DisplayType fieldType = fieldMap.get(fieldName).getDescribe().getType();
                                system.debug('theField fieldType : '+fieldType);
                                Object rawValue = entry.get(fieldName);
                                system.debug('theField rawValue : '+rawValue);
                                
                                String rawString = String.valueOf(rawValue).trim().replaceAll(',','');
                                Object finalValue;
                                
                                switch on fieldType {
                                    when Boolean {
                                        finalValue = rawString.toLowerCase() == 'true' || rawString == '1';
                                    }
                                    when Double, Currency {
                                        if(rawString.contains(','))
                                        {
                                            rawString.replaceAll(',','');
                                        }
                                        finalValue = Decimal.valueOf(rawString);
                                    }
                                    when Integer {
                                        if(rawString.contains(','))
                                        {
                                            rawString.replaceAll(',','');
                                        }
                                        finalValue = Integer.valueOf(rawString);
                                    }
                                    when Date {
                                        finalValue = Date.valueOf(rawString);
                                    }
                                    when DATETIME {
                                        //String rawString = '2025-07-14T12:24:15.000+00:00';
                                        String rawDateTime = (String) rawString; // from the JSON
                                        String cleaned = rawDateTime
                                            .replace('T', ' ')
                                            .replace('.000Z', '')
                                            .replace('Z', '')
                                            .replaceFirst('[\\+\\-]\\d{2}:\\d{2}$', '')
                                            .substring(0, 19);                                        
                                        finalValue = Datetime.valueOfGmt(cleaned);
                                    }                                    
                                    when String, TextArea, Email, Phone, Url, Picklist {
                                        finalValue = rawString;
                                    }
                                    when else {
                                        finalValue = rawString;
                                    }
                                }
                                record.put(fieldName, finalValue);
                            }
                        }
                    }
                }
                resultRecords.add(record);
            }
        }
        if (!resultRecords.isEmpty()) {
            insert resultRecords;
        }
        if(isDone)
        	return 'true';
        else
            return 'false';
    }
}