/**
 * @name        smartSyncInitializer
 * @description Handles Calculated Insight metadata snapshot and dynamic sObject creation.
 * @author      Debanjan Mukherjee
 * @created     2025-06-19
 */
public with sharing class SmartSyncInitializer {
    /**
    * @description Custom exception for  failures
    */
    public class SmartSyncException extends Exception {}
    /**
    *@description Metadata for Calculated Insights
     */
    @TestVisible
    public static List<CiMetadataHelper.metadata> lstInsightMetas;
    /**
     * @description Creates or updates Calculated Insights and their fields based on metadata.
     */
    @TestVisible public static boolean forceException = false;
    /*
    * @description Creates or updates Calculated Insights and their fields based on metadata.
    * @return Set of String - Developer Names of the created or updated Calculated Insights.
     */
    public static Set<String> createCiMetaSnapshots() {
        if (!Schema.sObjectType.Calculated_Insight__c.isCreateable() ||
            !Schema.sObjectType.Calculated_Insight__c.fields.Developer_Name__c.isCreateable() ||
            !Schema.sObjectType.Insight_Field__c.isCreateable() ||
            !Schema.sObjectType.Insight_Field__c.fields.Developer_Name__c.isCreateable()) {
            throw new SmartSyncException('You do not have permission to create Calculated Insight or Insight Field records.');
        }
        Set<String> setCiNames = new Set<String>();
        try
        {
            if ((Test.isRunningTest() && forceException)) {
                throw new SmartSyncException('Invalid Inputs');
            }
            lstInsightMetas = CiMetadataHelper.fetchInsightMetas();
        } catch (Exception ex) {
            throw new SmartSyncException('Failed to upsert Calculated Insights: ' + ex.getMessage());
        }
            List<Calculated_Insight__c> ciListToUpsert = new List<Calculated_Insight__c>();
            Map<String, List<Insight_Field__c>> ciFieldsMap = new Map<String, List<Insight_Field__c>>();
            for (CiMetadataHelper.metadata meta : lstInsightMetas) {
                String ciDevName = meta.name.replace('__cio', '');
                if(!ciDevName.endsWith('_DAY') && !ciDevName.endsWith('_HOUR') && !ciDevName.endsWith('_MONTH') && !ciDevName.endsWith('_QUARTER') && !ciDevName.endsWith('_YEAR'))
                {
                    setCiNames.add(ciDevName);
                    Calculated_Insight__c ci = new Calculated_Insight__c(
                        Name = meta.name,
                        latestSuccessfulProcessTime__c = meta.latestSuccessfulProcessTime,
                        displayName__c = meta.displayName,
                        latestProcessTime__c = meta.latestProcessTime,
                        partitionBy__c = meta.partitionBy,
                        Developer_Name__c = ciDevName
                    );
                    ciListToUpsert.add(ci);
                    List<Insight_Field__c> fieldsForCi = new List<Insight_Field__c>();
                    for (CiMetadataHelper.measures measure : meta.measures) {
                        fieldsForCi.add(prepareInsightField(ciDevName, measure.name, measure.displayName, measure.businessType, measure.type, 'Measure'));
                    }
                    for (CiMetadataHelper.dimensions dim : meta.dimensions) {
                        fieldsForCi.add(prepareInsightField(ciDevName, dim.name, dim.displayName, dim.businessType, dim.type, 'Dimension'));
                    }
                    ciFieldsMap.put(ciDevName, fieldsForCi);
                }
            }
        try {
            upsert ciListToUpsert Developer_Name__c;
        } catch (Exception ex) {
            throw new SmartSyncException('Failed to upsert Calculated Insights: ' + ex.getMessage());
        }
        List<Insight_Field__c> ciFieldsToUpsert = new List<Insight_Field__c>();
        for (Calculated_Insight__c ciRecord : ciListToUpsert) {
            List<Insight_Field__c> relatedFields = ciFieldsMap.get(ciRecord.Developer_Name__c);
            for (Insight_Field__c field : relatedFields) {
                field.Calculated_Insight__c = ciRecord.Id;
            }
            ciFieldsToUpsert.addAll(relatedFields);
        }
        try {
            upsert ciFieldsToUpsert Developer_Name__c;
        } catch (Exception ex) {
            throw new SmartSyncException('Failed to upsert Insight Fields: ' + ex.getMessage());
        }
        return setCiNames;
    }
     /*
    * @description Creates or updates Calculated Insights and their fields based on metadata.
    * @return Set of String - Developer Names of the created or updated Calculated Insights.
     */
    public static Set<String> createSpecificCiMetaSnapshots(String objectDevName) {
        if (!Schema.sObjectType.Calculated_Insight__c.isCreateable() ||
            !Schema.sObjectType.Calculated_Insight__c.fields.Developer_Name__c.isCreateable() ||
            !Schema.sObjectType.Insight_Field__c.isCreateable() ||
            !Schema.sObjectType.Insight_Field__c.fields.Developer_Name__c.isCreateable()) {
            throw new SmartSyncException('You do not have permission to create Calculated Insight or Insight Field records.');
        }
        Set<String> setCiNames = new Set<String>();
        try
        {
            if ((Test.isRunningTest() && forceException)) {
                throw new SmartSyncException('Invalid Inputs');
            }
            if(String.isNotBlank(objectDevName))
            {
            	lstInsightMetas = CiMetadataHelper.fetchSpecificInsightMeta(objectDevName+'__cio');
            }
            system.debug(lstInsightMetas);
        } catch (Exception ex) {
            throw new SmartSyncException('Failed to upsert Calculated Insights: ' + ex.getMessage());
        }
        Calculated_Insight__c ci = [Select Id,Name,latestSuccessfulProcessTime__c,displayName__c,latestProcessTime__c,partitionBy__c, Developer_Name__c from Calculated_Insight__c where Developer_Name__c=:objectDevName Limit 1];
        CiMetadataHelper.metadata meta = lstInsightMetas[0];
         system.debug(meta);
        setCiNames.add(objectDevName);
        ci.latestSuccessfulProcessTime__c = meta.latestSuccessfulProcessTime;
        ci.displayName__c = meta.displayName;
        ci.latestProcessTime__c = meta.latestProcessTime;
        ci.partitionBy__c = meta.partitionBy;
        List<Insight_Field__c> fieldsForCi = new List<Insight_Field__c>();
        for (CiMetadataHelper.measures measure : meta.measures) {
            fieldsForCi.add(prepareInsightField(objectDevName, measure.name, measure.displayName, measure.businessType, measure.type, 'Measure'));
        }
        for (CiMetadataHelper.dimensions dim : meta.dimensions) {
            fieldsForCi.add(prepareInsightField(objectDevName, dim.name, dim.displayName, dim.businessType, dim.type, 'Dimension'));
        }
		system.debug(fieldsForCi);
        try {
            update ci;
        } catch (Exception ex) {
            throw new SmartSyncException('Failed to upsert Calculated Insights: ' + ex.getMessage());
        }
        List<Insight_Field__c> ciFieldsToUpsert = new List<Insight_Field__c>();
        for (Insight_Field__c field : fieldsForCi) {
            field.Calculated_Insight__c = ci.Id;
        }
        ciFieldsToUpsert.addAll(fieldsForCi);
        try {
            insert ciFieldsToUpsert;
        } catch (Exception ex) {
            throw new SmartSyncException('Failed to upsert Insight Fields: ' + ex.getMessage());
        }
        return setCiNames;
    }
    /**
     * @description Fetches the details of the chosen Calculated Insight.
     * @param ciName Developer Name of the Calculated Insight Object (without __c suffix).
     * @return List of Insight_Field__c records associated with the specified Calculated Insight.
     * @throws SmartSyncException if access to required fields is denied or no CI details are found.
     */
    public static List<Insight_Field__c> getDetailsOfChosenCi(String ciName) {
        if (!Schema.sObjectType.Insight_Field__c.fields.Calculated_Insight__c.isAccessible() ||
            !Schema.sObjectType.Insight_Field__c.fields.Name.isAccessible() ||
            !Schema.sObjectType.Insight_Field__c.fields.Developer_Name__c.isAccessible() ||
            !Schema.sObjectType.Insight_Field__c.fields.displayName__c.isAccessible() ||
            !Schema.sObjectType.Insight_Field__c.fields.field_type__c.isAccessible()) {
            throw new SmartSyncException('You do not have access to required Insight Field fields');
        }
        List<Insight_Field__c> fields = [
            SELECT Id, Name, Calculated_Insight__c, Developer_Name__c,
                   displayName__c, field_type__c,
                   Calculated_Insight__r.displayName__c,
                   Calculated_Insight__r.Developer_Name__c
            FROM Insight_Field__c
            WHERE Calculated_Insight__r.Developer_Name__c = :ciName //Limit 10
        ];

        if (fields.isEmpty()) {
            throw new SmartSyncException('No CI Details found - Please perform initial sync');
        }
        return fields;
    }
    /**
     * @description Starts the deployment process for the selected Calculated Insight.
     * @param ciName Developer Name of the Calculated Insight Object (without __c suffix).
     * @param permissionSetName Name of the permission set to assign.
     * @param permissionSetLabel Label of the permission set to assign.
     * @return true if deployment is initiated successfully, false otherwise.
     * @throws SmartSyncException if any error occurs during the process.
     */
    public static Boolean getSelectedCI(String ciName,string permissionSetName, string permissionSetLabel) {
        try {
            List<Insight_Field__c> insightFields = getDetailsOfChosenCi(ciName);
            String objectName = insightFields[0].Calculated_Insight__r.displayName__c;
            String objectAPI = insightFields[0].Calculated_Insight__r.Developer_Name__c + '__c';
            String objectPlural = objectName + 's';
            List<String> fieldApiNames = new List<String>();
            for(Insight_Field__c field:insightFields)
            {
                fieldApiNames.add(field.Name);
            }
            String cioApiName = ciName.endsWith('__c')?ciName+'io':ciName;
        	cioApiName = cioApiName.endsWith('__cio')?cioApiName:ciName+'__cio';
            //MetaDataServiceHandler.createCustomObject(objectName, objectAPI, objectPlural);
			if (!Test.isRunningTest()) {
            	Database.executeBatch(new CreateCustomObjectBatch(objectName, objectAPI, objectPlural, permissionSetName,permissionSetLabel),1);
                initiateDeployment(cioApiName, fieldApiNames);}
            return true;
        } catch (Exception ex) {
            throw new SmartSyncException('Failed start deployments ' + ex.getMessage());
        }
    }
	/**
     * @description Initiates deployment by queueing the invoker.
     * @param cioApiName API name of the object.
     * @param fieldApiNames List of field API names to include.
     */
    public static void initiateDeployment(String cioApiName, List<String> fieldApiNames) {
        if (String.isBlank(cioApiName) || fieldApiNames == null || fieldApiNames.isEmpty()) {
            throw new SmartSyncException('Invalid input provided for flow deployment');
        }
        System.enqueueJob(new CreateFlowInvokerQueueable(cioApiName, fieldApiNames));
    }
    private static Insight_Field__c prepareInsightField(
        String ciDevName,
        String name,
        String displayName,
        String businessType,
        String type_x,
        String fieldGroup
    ) {
        return new Insight_Field__c(
            Name = name,
            displayName__c = displayName?.replace('__c','').replace('_',' '),
            businessType__c = businessType,
            field_type__c = type_x,
            Measure_Dimension__c = fieldGroup,
            Insight__c = ciDevName,
            Developer_Name__c = ciDevName + '_' + name.replace('__c', '') + '_' + fieldGroup,
            Field_Group__c = fieldGroup
        );
    }
}