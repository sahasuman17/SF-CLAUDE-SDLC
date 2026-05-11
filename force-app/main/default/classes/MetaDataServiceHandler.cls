/**
 * @description Utility class for dynamic creation and manipulation of Custom Metadata using Salesforce Metadata API.
 * Handles object and field creation programmatically from Apex.
 * @author Debanjan Mukherjee
 * @created 2025-06-19
 */
public class MetaDataServiceHandler {
    @TestVisible private static Boolean runStub = false;
    /**
     * @description Custom exception for Metadata failures
     */
	public class MetadataServiceException extends Exception {}

    /**
     * @description Creates a custom object with specified properties.
     * @param objectName Name of the custom object
     * @param objectAPI API name of the custom object (should end with __c)
     * @param objectPlural Plural label of the custom object
     */
    public static void createCustomObject(String objectName, String objectAPI, String objectPlural) {
        MetadataService.MetadataPort metadataservice = new MetadataService.MetadataPort();
        metadataservice.SessionHeader = new MetadataService.SessionHeader_element();
        metadataservice.SessionHeader.sessionId = UserInfo.getSessionId();
        MetadataService.CustomObject customObject = new MetadataService.CustomObject();
        customObject.fullName = objectAPI;
        customObject.label = objectName;
        customObject.pluralLabel = objectPlural;
        customObject.nameField = new MetadataService.CustomField();
        customObject.nameField.type_x = 'Text';
        customObject.nameField.label = 'Name';
        customObject.deploymentStatus = 'Deployed';
        customObject.sharingModel = 'ReadWrite';
        List<MetadataService.CustomObject> objectList = new List<MetadataService.CustomObject> { customObject };
        try
        {
            if (Test.isRunningTest()) {
                throw new MetadataServiceException('Will not call Metadata Service for Tests');
            }
        	metadataservice.createMetadata(objectList);
        }
        catch(Exception ex)
        {
            throw new MetadataServiceException('Field to create object: ' + ex.getMessage());
        }
    }
    /**
    * @description Creates custom fields on a custom object.
    * @param lstFieldDefs List of field definitions to create
    * @param lstNumFields List of field definitions for number fields to create
    */
    public static void createFields(List<fieldDef> lstFieldDefs,List<MetaDataServiceHandler.fieldDefNumber> lstNumFields) {
        MetadataService.MetadataPort metadataservice = new MetadataService.MetadataPort();
        metadataservice.SessionHeader = new MetadataService.SessionHeader_element();
        metadataservice.SessionHeader.sessionId = UserInfo.getSessionId();
        List<MetadataService.CustomField> fieldsToCreate = new List<MetadataService.CustomField>();
		List<string> lstFieldFullNames = new List<string>();
        for (fieldDef theField : lstFieldDefs) {
            MetadataService.CustomField customField = createField(
                new MetadataService.CustomField(),
                theField.fullName,
                theField.label,
                theField.type_x,
                theField.length
            );
            fieldsToCreate.add(customField);
            lstFieldFullNames.add(theField.fullName);
        }
		for (fieldDefNumber theField : lstNumFields) {
            MetadataService.CustomField customField = createNumField(
                new MetadataService.CustomField(),
                theField.fullName,
                theField.label,
                theField.type_x,
                theField.precision,
                theField.scale
            );
            fieldsToCreate.add(customField);
            lstFieldFullNames.add(theField.fullName);
        }
        List<MetadataService.Metadata> lstMetadata = new List<MetadataService.Metadata>();
        lstMetadata.addAll(fieldsToCreate);
        MetadataService.SaveResult[] results;
        if (Test.isRunningTest()) {
            throw new MetadataServiceException('Will not call Metadata Service for Tests');
        }
        results = metadataservice.createMetadata(fieldsToCreate);
        string errorMessage='';
        // Proceed only if field creation succeeded
        if (results == null || !results[0].success) {
            for (MetadataService.Error err : results[0].errors) {
                errorMessage = errorMessage + err.message;
                // $&
            }
            throw new MetadataServiceException('Field creation error: ' + errorMessage);
        }
    }
    /**
     * @description Creates a custom field with specified properties.
     * @param customField MetadataService.CustomField instance to populate
     * @param fullName Full name of the field (e.g., My_Object__c.My_Field__c)
     * @param label Label for the field
     * @param type_x Data type of the field (e.g., Text, Number)
     * @param length Length of the field (if applicable)
     * @return MetadataService.CustomField populated with provided values
     * @SuppressWarnings
     * Calls to WSDL generated classes
     */
    public static MetadataService.CustomField createField(
        MetadataService.CustomField customField,
        String fullName,
        String label,
        String type_x,
        Integer length
    ) {
        customField.fullName = fullName;
        customField.label = label;
        customField.type_x = type_x;
        customField.length = length;
        return customField;
    }
    /**
     * @description Creates a custom number field with specified properties.
     * @param customField MetadataService.CustomField instance to populate
     * @param fullName Full name of the field (e.g., My_Object__c.My_Number_Field__c)
     * @param label Label for the field
     * @param type_x Data type of the field (should be 'Number')
     * @param precision Precision of the number field
     * @param scale Scale of the number field
     * @return MetadataService.CustomField populated with provided values
     * @SuppressWarnings
     * Calls to WSDL generated classes
     */
	public static MetadataService.CustomField createNumField(
        MetadataService.CustomField customField,
        String fullName,
        String label,
        String type_x,
        Integer precision,
        Integer scale
    ) {
        customField.fullName = fullName;
        customField.label = label;
        customField.type_x = type_x;
        customField.precision = precision;
        customField.scale = scale;
        return customField;
    }
    /**
     * @description Class to hold field definitions for custom fields.
     * @SuppressWarnings
     * Calls to WSDL generated classes
     */
    public class fieldDef {
        /**
         * @description Full name of the field, including the object API name (e.g., My_Object__c.My_Field__c)
         */
        public String fullName { get; set; }
        /**
         * @description Label for the field
         */
        public String label { get; set; }
        /**
         * @description Data type of the field (e.g., Text, Number)
         */
        public String type_x { get; set; }
        /**
         * @description Length of the field (if applicable, e.g., for Text fields)
         */
        public Integer length { get; set; }
    }
    /**
     * @description Class to hold field definitions for custom fields.
     */
    public class fieldDefNumber {
        /**
         * @description Full name of the field, including the object API name (e.g., My_Object__c.My_Number_Field__c)
         */
        public String fullName { get; set; }
        /**
         * @description Label for the field
         */
        public String label { get; set; }
        /**
         * @description Data type of the field (should be 'Number')
         */
        public String type_x { get; set; }
        /**
         * @description Precision of the number field
         */
        public Integer precision { get; set; }
        /**
         * @description Scale of the number field
         */
        public Integer scale { get; set; }
    }
}