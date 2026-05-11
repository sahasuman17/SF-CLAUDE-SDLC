/**
*@name CsvLineProcessorBatch
* @description CsvLineProcessorBatch processes CSV results returned from the Data Cloud Bulk API job.
 *
 * It parses each CSV line into increment data, applies data transformations,
 * and then performs upsert operations against a specified object based on dynamic fields.
 *
 * The class includes retry-safe logic and cleanup for successfully processed stage records.
 * It is designed to be PMD and Salesforce Code Analyzer compliant.
 *
 * @author Debanjan Mukherjee
 * @created 01 Jul 2024
 */
public with sharing class CsvLineProcessorBatch implements Database.Batchable<String>, Database.Stateful {
    /**@description
     * Custom exception for SmartSync-specific errors.
     */
    public class SmartSyncException extends Exception {}
    private final String objectApiName;
    private final String sObjectApi;
    private final String keyField;
    private final List<String> csvLines;
    private List<String> failedStageRecordIds;
    private List<String> successStageRecordIds;
     @TestVisible
    private static Map<String, Id> cachedKeyToIdMap;
    /**
     * Constructor to initialize the batch processor with object API name, key field, and raw CSV lines.
     * @description This constructor sets up the batch with the necessary parameters to process CSV data.
     * @param objectApiName The name of the object to upsert into.
     * @param keyField The external ID or matching field.
     * @param csvLines The CSV data including the header.
     */
    public CsvLineProcessorBatch(String objectApiName, String keyField, List<String> csvLines) {
        this.objectApiName = objectApiName;
        this.keyField = keyField;
        this.csvLines = csvLines;
        if(String.isNotBlank(objectApiName))
        	this.sObjectApi = objectApiName.endsWith('__c') ? objectApiName : objectApiName + '__c';
        failedStageRecordIds = new List<String>();
        successStageRecordIds = new List<String>();
        cachedKeyToIdMap = getKeyToIdMap(sObjectApi, keyField);
    }

    /**
     * Batch start method that returns CSV lines excluding header.
     * @description This method is called at the start of the batch process to prepare the scope of data to be processed.
     * @param bc The batchable context.
     * @return Iterable of CSV lines.
     */
    public Iterable<String> start(Database.BatchableContext bc) {
        try {
            if (csvLines == null || csvLines.isEmpty()) {
                throw new SmartSyncException('Missing data: CsvLineProcessorBatch.csvLines');
            }
            List<String> scopeLines = new List<String>();
            for (Integer i = 1; i < csvLines.size(); i++) {
                scopeLines.add(csvLines[i]);
                System.debug(csvLines[i]);
            }
            return scopeLines;
        } catch (Exception ex) {
            SmartSyncUtil.publishEvent('Incremental Sync', 'Failed to Process Data', 'Error ');
            ErrorLogger.logErrorFromException('High', 'CsvLineProcessorBatch', 'Start',ex, 'Incremental Sync - Failed to Process Data');
        	List<String> lstString = new List<String>();
            Return lstString;
        }
    }

    /**
     * Batch execute method that processes the CSV lines, creates or updates records.
     *  @description This method is called for each batch of CSV lines to parse the data,
     * @param bc The batchable context.
     * @param lines The CSV lines.
     */
    public void execute(Database.BatchableContext bc, List<String> lines) {
        try {
            if (String.isBlank(objectApiName)) {
                System.debug('CsvLineProcessorBatch '+1);
                throw new SmartSyncException('Missing data: CsvLineProcessorBatch.objectApiName');                
            }
            if (String.isBlank(keyField)) {
                System.debug('CsvLineProcessorBatch '+2);
                throw new SmartSyncException('Missing data: CsvLineProcessorBatch.keyField');                
            }
            if (lines == null || lines.isEmpty()) {
                System.debug('CsvLineProcessorBatch '+3);
                throw new SmartSyncException('Missing data: CsvLineProcessorBatch.lines');                
            }

            if (cachedKeyToIdMap == null || cachedKeyToIdMap.isEmpty()) {
                System.debug('CsvLineProcessorBatch '+4);
                cachedKeyToIdMap = fetchExistingKeyIdMap(sObjectApi, keyField);
            }
            System.debug('CsvLineProcessorBatch '+5);
            
          
            Map<String, Wrapper> keyToLatestRecord = new Map<String, Wrapper>();
			
            for (String line : lines) {                
                System.debug('CsvLineProcessorBatch line before parseCsvLine '+line);
                List<String> fields = parseCsvLine(line);
                 System.debug('CsvLineProcessorBatch line after parseCsvLine '+line);
				System.debug('CsvLineProcessorBatch fields '+fields);
                if (fields.size() < 5) {
                    continue;
                }

                Wrapper wrapper = new Wrapper();
                wrapper.StageRecordId = fields[0];
                wrapper.StageAutoNumber = fields[1];
                wrapper.CiName = fields[2];
                wrapper.LastModifiedDateInStage = parseBulkApiDate(fields[3]);
                wrapper.Increment_Data = fields[4];
				System.debug('wrapper'+wrapper);
                Map<String, Object> incDataMap = parseIncrementData(wrapper.Increment_Data);
                System.debug('CsvLineProcessorBatch incDataMap '+incDataMap);
                if (incDataMap == null) {
                    continue;
                }

                Object keyValue = incDataMap.get(keyField);
                System.debug('CsvLineProcessorBatch keyValue '+keyValue);
                if (keyValue == null || String.valueOf(keyValue).trim() == '') {
                    throw new SmartSyncException('Missing data: keyField ' + keyField + ' for stage record ' + wrapper.StageRecordId);
                }

                wrapper.keyFieldData = String.valueOf(keyValue);
				System.debug('CsvLineProcessorBatch wrapper.keyFieldData '+wrapper.keyFieldData);
                if (!objectApiName.equalsIgnoreCase(wrapper.CiName)) {
                    continue;
                }

                if (!keyToLatestRecord.containsKey(wrapper.keyFieldData)
                    || (wrapper.LastModifiedDateInStage != null &&
                        wrapper.LastModifiedDateInStage.getTime() > keyToLatestRecord.get(wrapper.keyFieldData).LastModifiedDateInStage.getTime())) {
                    keyToLatestRecord.put(wrapper.keyFieldData, wrapper);
                }else
                {
                    //We will also remove the record in Stage which ignored due to not latest however post first Full Sync Completed
                    successStageRecordIds.add(wrapper.StageRecordId);
                }
                
                System.debug('wrapper.keyFieldData: '+wrapper.keyFieldData );
                System.debug('wrapper : '+wrapper);
            }
			
            List<SObject> lstRecords = new List<SObject>();
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(sObjectApi).getDescribe().fields.getMap();

            for (Wrapper wrapper : keyToLatestRecord.values()) {
                SObject record = (SObject) Type.forName('Schema.' + sObjectApi).newInstance();
                Map<String, Object> dataMap = parseIncrementData(wrapper.Increment_Data);

                if (dataMap != null) {
                    for (String fieldName : dataMap.keySet()) {
                        system.debug('fieldName : '+fieldName);
                        if (fieldMap.containsKey(fieldName)) {
                            try {
                                Schema.DisplayType fieldType = fieldMap.get(fieldName).getDescribe().getType();
                                system.debug('theField fieldType : '+fieldType);
                                Object rawValue = dataMap.get(fieldName);
                                system.debug('theField rawValue : '+rawValue);
                                if (rawValue == null) {
                                    throw new SmartSyncException('Missing data: Field ' + fieldName + ' in stage record ' + wrapper.StageRecordId);
                                }
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
                                    when Datetime {
                                        finalValue = Datetime.valueOfGmt(rawString.replace('T', ' ').replace('Z', ''));
                                    }
                                    when String, TextArea, Email, Phone, Url, Picklist {
                                        finalValue = rawString;
                                    }
                                    when else {
                                        finalValue = rawString;
                                    }
                                }
                                System.debug('theField fieldName : '+fieldName);
                                System.debug('theField finalValue : '+finalValue);
                                record.put(fieldName, finalValue);
                                //record.put('Id', null);
                            } catch (Exception ex) {
                                ErrorLogger.logErrorFromException('High', 'CsvLineProcessorBatch', 'Start',ex, 'Incremental Sync - Failed to Process Data');

                            }
                        }
						system.debug('theRecord csvBatch :'+record);
                    }
                    
                    //record.put(keyField, wrapper.keyFieldData);
                    lstRecords.add(record);
                }
            }

            List<SObject> lstRecordsWithId = populateRecordIdsFromCache(lstRecords, keyField);
            Database.UpsertResult[] results = Database.upsert(lstRecordsWithId, false);

            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess())
                {
                    //successStageRecordIds.add(result.getId());
                    successStageRecordIds.add(keyToLatestRecord.values()[i].StageRecordId);
                }else
                {
                    failedStageRecordIds.add(keyToLatestRecord.values()[i].StageRecordId);
                }
            }

            if (!failedStageRecordIds.isEmpty()) {
                throw new SmartSyncException('Incremental Sync - Unable to process Data Cloud Staged records with ids : ' + failedStageRecordIds);

            }
        } catch (Exception ex) {
            SmartSyncUtil.publishEvent('Incremental Sync', 'Failed to Process Data', 'Error ');
            ErrorLogger.logErrorFromException('High', 'CsvLineProcessorBatch', 'Execute',ex, 'Incremental Sync-Failed to Process Data for record with Ids in Staging Table '+failedStageRecordIds);
        	SmartSyncUtil.updateCalculatedInsightFields(objectApiName,null,Datetime.now(),null,null,'Failed',null);
        }
    }

    /**
     * Batch finish method that deletes the processed staging records.
     *  @description This method is called after all batches are processed to clean up staging records.
     * @param bc The batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        if (!successStageRecordIds.isEmpty())
        {
            if(!Test.isRunningTest())
            {
            	Database.executeBatch(new BulkStageDeleterBatch(successStageRecordIds), 100);
            }            
        }
        SmartSyncUtil.updateCalculatedInsightFields(objectApiName,null,Datetime.now(),null,null,'Completed',null);
    }
	
    // --- Helpers ---
    /**
     *@description Parses a CSV line into a list of string values, respecting quoted fields.
     * This method handles values enclosed in double quotes and correctly splits
     * the line using commas as delimiters while preserving values with embedded commas.
     *
     * @author Debanjan Mukherjee
     * @created 01 Jul 2024
     * @param line A single line from a CSV file (excluding the header).
     * @return A list of trimmed string values parsed from the CSV line.
     */
    private static List<String> parseCsvLine(String line) {
        List<String> values = new List<String>();
        /*
        Boolean inQuotes = false;
        String curr = '';

        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);
            if (ch == '"') {
                inQuotes = !inQuotes;
            } else if (ch == ',' && !inQuotes) {
                values.add(curr.trim());
                curr = '';
            } else {
                curr += ch;
            }
        }
        values.add(curr.trim());
		*/
        line = line.substring(1, line.length() - 1);
        //line = line.replace('", "','","');
        values = line.split('","');
        return values;
    }
	 /**
     * Parses a JSON-like string from the Increment_Data column into a key-value map.
     *  * @description This method attempts to deserialize a string that may represent
     * The method ensures robustness against common formatting issues such as unquoted
     * field names or extra escaping. It replaces malformed patterns and attempts deserialization.
     *
     * @author Debanjan Mukherjee
     * @created 01 Jul 2024
     * @param jsonStr A raw string (often malformed JSON) representing increment data.
     * @return A map of field names to values extracted from the increment data, or null if parsing fails.
     */
    private static Map<String, Object> parseIncrementData(String jsonStr) {
        System.debug('csvLineProcessorBatch parseIncrementData received jsonStr'+jsonStr);
        if (String.isBlank(jsonStr)) return null;

        try {
            /*
            // Fix double-escaped quotes ("" -> ")
            jsonStr = jsonStr.replaceAll('""', '"');

            // If field names are unquoted, fix them
            if (!jsonStr.contains('\"')) {
                jsonStr = jsonStr.replaceAll('([a-zA-Z0-9_]+):', '"$1":');
                jsonStr = jsonStr.replaceAll(': ([^\",}{\\s]+)', ': "$1"');
            }
			*/
			jsonStr = jsonStr.replaceAll('""','"');
            Map<String, Object> mapItems = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
            for (String key  : mapItems.keySet()) {
                System.debug('key: ' + key);
                System.debug('Value: ' + mapItems.get(key));
            }
            return mapItems;
        } catch (Exception ex) {
            // $&
            return null;
        }
    }
	/**
     * @description Retrieves a map of key field value to record Id for a given sObject.     *
     * @param rawDate The date which have come from Bulk API response
     * @return Datetime - a salesforce compatible DateTime.
     */
    private static Datetime parseBulkApiDate(String rawDate) {
        if (String.isBlank(rawDate)) return null;

        try {
            if (rawDate.endsWith('Z')) {
                rawDate = rawDate.removeEnd('Z');
            }

            rawDate = rawDate.replace('T', ' '); // Replace T with space

            if (rawDate.length() == 19) {
                rawDate += '.000';
            }

            return Datetime.valueOfGmt(rawDate);
        } catch (Exception e) {
            // $&
            return null;
        }
    }
    /**
     * @description Wrapper class to hold parsed CSV line data.
     * Contains fields for stage record ID, auto number, CI name, last modified date,
     * increment data, and key field data.
     */
    public class Wrapper {
        public String StageRecordId;
        public String StageAutoNumber;
        public String CiName;
        public Datetime LastModifiedDateInStage;
        public String Increment_Data;
        public String keyFieldData;
    }
    /**
     * Retrieves a map of key field value to record Id for a given sObject.
     *  @description This method queries the specified object for existing records
     * @param objectApiName The API name of the target custom object (e.g., 'Warranty_Parts_Per_Claims_Dup2__c').
     * @param keyField The API name of the key field on the object (e.g., 'claim_number__c').
     * @return Map of keyField value to record Id.
     */
    @AuraEnabled
    public static Map<String, Id> fetchExistingKeyIdMap(String objectApiName, String keyField) {
        Map<String, Id> keyToIdMap = new Map<String, Id>();

        if (String.isBlank(objectApiName) || String.isBlank(keyField)) {
            return keyToIdMap;
        }

        String query = 'SELECT Id, ' + String.escapeSingleQuotes(keyField) + ' FROM ' + objectApiName;
		// $&
        try {
            List<SObject> results = Database.query(query);
            for (SObject record : results) {
                Object keyVal = record.get(keyField);
                if (keyVal != null && String.valueOf(keyVal).trim() != '') {
                    keyToIdMap.put(String.valueOf(keyVal).trim(), (Id)record.get('Id'));
                }
            }
        } catch (Exception ex) {
            // Optional: add logging or custom exception handling here
            // $&
        }

        return keyToIdMap;
    }
	/**
     * Returns the key-to-Id map for the specified object and key field.
     * Fetches from the database only once and caches for reuse.
     *  @description This method retrieves a map of key field values to record Ids for a given sObject.
     * @param objectApiName The API name of the sObject (e.g., 'Warranty_Parts_Per_Claims_Dup2__c').
     * @param keyField The API name of the key field (e.g., 'claim_number__c').
     * @return Cached or freshly queried map of key field value to record Id.
     */
    public static Map<String, Id> getKeyToIdMap(String objectApiName, String keyField) {
        if (cachedKeyToIdMap == null || cachedKeyToIdMap.isEmpty()) {
            cachedKeyToIdMap = fetchExistingKeyIdMap(objectApiName, keyField);
        }
        return cachedKeyToIdMap;
    }
	/**
     * Populates the Id field on each record based on cached key-to-Id mapping.
     * Only records with a matching key in the map will get their Ids populated.
     *  @description This method takes a list of SObjects with a specified key field,
     * @param lstRecords The input records with key field populated.
     * @param keyField The API name of the key field (e.g., 'claim_number__c').
     * @return The list of SObjects with Ids populated if matched.
     */
    public static List<SObject> populateRecordIdsFromCache(List<SObject> lstRecords, String keyField) {
        List<SObject> processedRecords = new List<SObject>();

        if (lstRecords == null || lstRecords.isEmpty() || String.isBlank(keyField)) {
            return processedRecords;
        }

        if (cachedKeyToIdMap == null || cachedKeyToIdMap.isEmpty()) {
            // $&
            return lstRecords;
        }

        for (SObject record : lstRecords) {
            Object keyValObj = record.get(keyField);
            if (keyValObj != null) {
                String keyVal = String.valueOf(keyValObj).trim();
                if (cachedKeyToIdMap.containsKey(keyVal)) {
                    record.put('Id', cachedKeyToIdMap.get(keyVal));
                }
            }
            processedRecords.add(record);
        }
        return processedRecords;
    }
}