public with sharing class DynamicDataFetcher {
    public class DynamicResultWrapper {
        @AuraEnabled public Boolean hasRecords;
        @AuraEnabled public String message;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public List<ColumnMetadata> columns;
        @AuraEnabled public List<Map<String, Object>> data;
    }

    public class ColumnMetadata {
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;

        public ColumnMetadata(String label, String fieldName) {
            this.label = label;
            this.fieldName = fieldName;
        }
    }

    public class InsightOptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    @AuraEnabled(cacheable=true)
    public static List<InsightOptionWrapper> getCalculatedInsights() {
        List<InsightOptionWrapper> options = new List<InsightOptionWrapper>();
        for (Calculated_Insight__c ci : [
            SELECT DisplayName__c, Developer_Name__c
            FROM Calculated_Insight__c
            WHERE DisplayName__c != null AND Developer_Name__c != null
            ORDER BY DisplayName__c
        ]) {
            InsightOptionWrapper wrapper = new InsightOptionWrapper();
            wrapper.label = ci.DisplayName__c;
            wrapper.value = ci.Developer_Name__c;
            options.add(wrapper);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static DynamicResultWrapper fetchRecordsWithMetadata(
        String inputObjectName,
        String searchTerm,
        String searchField,
        String sortField,
        Integer pageSize,
        Integer offset
    ) {
        if (String.isBlank(inputObjectName)) {
            throw new AuraHandledException('Object name cannot be blank.');
        }

        String objectName = inputObjectName.trim();
        if (!objectName.endsWith('__c')) {
            objectName += '__c';
        }

        if (!Schema.getGlobalDescribe().containsKey(objectName)) {
            throw new AuraHandledException('Object ' + objectName + ' does not exist.');
        }

        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult describeResult = sObjType.getDescribe();

        Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
        List<String> fieldNames = new List<String>();
        List<ColumnMetadata> columnMeta = new List<ColumnMetadata>();

        Set<String> excludedFields = new Set<String>{
            'name','id','ownerid','isdeleted','createddate','createdbyid','lastmodifieddate','lastmodifiedbyid','systemmodstamp',
            'OwnerId', 'IsDeleted', 'Deleted',
            'CreatedById', 'CreatedBy',
            'LastModifiedById', 'LastModifiedBy',
            'SysModStamp'
        };

        for (String apiName : fieldMap.keySet()) {
            system.debug(apiName);
            if (!excludedFields.contains(apiName) && !apiName.contains('kq_')) 
            {
                Schema.DescribeFieldResult field = fieldMap.get(apiName).getDescribe();
                if (field.isAccessible()) {
                    fieldNames.add(apiName);
                    columnMeta.add(new ColumnMetadata(field.getLabel(), apiName));
                }
            }
        }

        fieldNames.sort();
        String fieldListStr = String.join(fieldNames, ',');
        String fullQuery = 'SELECT ' + fieldListStr + ' FROM ' + objectName;        
        String whereClause = '';
        if (!String.isBlank(searchField) && !String.isBlank(searchTerm)) {
            whereClause = ' WHERE '+searchField+' LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'';
            fullQuery = fullQuery + whereClause;
        }
		String orderByClause = '';
        if (!String.isBlank(sortField)) {
            orderByClause = ' Order By '+sortField;  
            fullQuery = fullQuery + orderByClause;
        }
        fullQuery = fullQuery + ' LIMIT :pageSize OFFSET :offset';
        String countQuery = 'SELECT COUNT() FROM ' + objectName + whereClause;
        Integer totalRecords = (Integer) Database.countQuery(countQuery);
        system.debug('DynamicDataFetcher: '+fullQuery);
        List<sObject> resultRecords = Database.query(fullQuery);

        List<Map<String, Object>> recordMaps = new List<Map<String, Object>>();
        for (sObject sobj : resultRecords) {
            Map<String, Object> row = new Map<String, Object>();
            for (String fname : fieldNames) {
                row.put(fname, sobj.get(fname));
            }
            recordMaps.add(row);
        }

        DynamicResultWrapper result = new DynamicResultWrapper();
        result.hasRecords = !recordMaps.isEmpty();
        result.message = result.hasRecords ? 'Total Records: ' + totalRecords : 'No records found.';
        result.totalCount = totalRecords;
        result.columns = columnMeta;
        result.data = recordMaps;
        return result;
    }
}