/**
 * @name        PermissionSetUpdater
 * @description Grants CRUD and Field-Level Security (FLS) to a Permission Set for a given sObject.
 *              Skips restricted system-managed fields such as Id, Name, MasterRecordId, etc.
 * @author      Debanjan Mukherjee
 * @created     2025-06-22
 */
public with sharing class PermissionSetUpdater {
    /**
    * @description Custom exception for  failures
    */
	public class MetadataServiceException extends Exception {}
    /**
     * @description Grants full object-level (CRUD + View All + Modify All) and field-level (Read/Edit)
     * access to a custom permission set. Handles ObjectPermissions insert carefully to avoid integrity errors.
     * @param sObjectApiName The API name of the object (e.g., Account, Custom_Object__c)
     * @param permissionSetName The DeveloperName of the custom permission set (e.g., Admin_Field_Access)
     */
    public static void grantFullAccessToPermissionSet(String sObjectApiName, String permissionSetName) {
        if (String.isBlank(sObjectApiName) || String.isBlank(permissionSetName)) {
            throw new IllegalArgumentException('Object API name and permission set name are required.');
        }
    	if(!sObjectApiName.endsWith('__c'))
        {
            sObjectApiName = sObjectApiName +'__c';
        }
        Map<String, Schema.SObjectType> allObjects = Schema.getGlobalDescribe();
        if (!allObjects.containsKey(sObjectApiName)) {
            throw new IllegalArgumentException('Invalid sObject type: ' + sObjectApiName);
        }
        PermissionSet ps = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :permissionSetName
            AND IsOwnedByProfile = false
            LIMIT 1
        ];
        if (ps == null) {
            throw new IllegalArgumentException('PermissionSetUpdater-grantFullAccessToPermissionSet issue: ' + permissionSetName);
        }
        Id permSetId = ps.Id;
        // Proceed with FLS
        Schema.DescribeSObjectResult objDescribe = allObjects.get(sObjectApiName).getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        Set<String> blockedFields = new Set<String>{
            'id', 'name', 'isdeleted', 'ownerid',
            'createdbyid', 'createddate', 'lastmodifiedbyid', 'lastmodifieddate',
            'systemmodstamp', 'masterrecordid', 'lastactivitydate',
            'lastvieweddate', 'lastreferenceddate'
        };
        List<FieldPermissions> fieldPermsToInsert = new List<FieldPermissions>();
        for (String fieldName : fieldMap.keySet()) {
            String lower = fieldName.toLowerCase();
            if (blockedFields.contains(lower)
                || lower.endsWith('__tag')
                || lower.endsWith('__history')
                || lower.endsWith('__share')
                || lower.contains('geocoded')
                || lower.contains('cleanstatus')) {
                continue;
            }
            FieldPermissions fls = new FieldPermissions(
                ParentId = permSetId,
                SObjectType = sObjectApiName,
                Field = sObjectApiName + '.' + fieldName,
                PermissionsRead = true,
                PermissionsEdit = true
            );
            fieldPermsToInsert.add(fls);
        }
    	try
        {
            if (!fieldPermsToInsert.isEmpty()) {
                insert fieldPermsToInsert;
            }
        }
        catch(Exception ex)
        {
            throw new MetadataServiceException('Field creation error: ' , ex);
        }
    }
    /**
     * @description Grants full object-level access (CRUD, View All, Modify All) to the specified permission set.
     * @param objectApiName The API name of the object (e.g., Account, Custom_Object__c)
     * @param permissionSetName The DeveloperName of a custom permission set (e.g., SmartSyncConsole)
     * @return Boolean True if inserted successfully, False otherwise.
     */
    public static Boolean grantObjectCrudAccessToPermissionSet(String objectApiName, String permissionSetName) {
        if (String.isBlank(objectApiName) || String.isBlank(permissionSetName)) {
            throw new IllegalArgumentException('Both object API name and permission set name are required.');
        }
    	if(!objectApiName.endsWith('__c'))
        {
            objectApiName = objectApiName +'__c';
        }
        // $&
        // Validate the sObject
        Map<String, Schema.SObjectType> allObjects = Schema.getGlobalDescribe();
        if (!allObjects.containsKey(objectApiName)) {
            throw new IllegalArgumentException('Invalid sObject type: ' + objectApiName);
        }
        // Query a valid, non-profile-based permission set
        List<PermissionSet> psList = [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name = :permissionSetName
            AND IsOwnedByProfile = false
            LIMIT 1
        ];
        if (psList.isEmpty()) {
            throw new IllegalArgumentException('Permission Set not found or is owned by a Profile: ' + permissionSetName);
        }
        Id permSetId = psList[0].Id;
        try {
            // Check if ObjectPermissions already exists to prevent duplicate insert
            List<ObjectPermissions> existing = [
                SELECT Id FROM ObjectPermissions
                WHERE ParentId = :permSetId AND SObjectType = :objectApiName
                LIMIT 1
            ];
            if (existing.isEmpty()) {
                ObjectPermissions op = new ObjectPermissions(
                    ParentId = permSetId,
                    SObjectType = objectApiName,
                    PermissionsCreate = true,
                    PermissionsRead = true,
                    PermissionsEdit = true,
                    PermissionsDelete = true,
                    PermissionsViewAllRecords = true,
                    PermissionsModifyAllRecords = true
                );
                insert op;
                return true;
            } else {
                // $&
                return false;
            }
        } catch (DmlException ex) {
            // $&
            return false;
        }
    }
	 /**
     * @description Grants full object-level permissions to a permission set using Metadata API.
     * @param objectApiName The API name of the custom object (e.g., My_Object__c)
     * @param permissionSetName The developer name of the permission set (e.g., SmartSyncConsole)
     * @param permissionSetLabel The label of the permission set (required for updateMetadata)
     */
    public static void grantCrudAccessViaMetadata(
        String objectApiName,
        String permissionSetName,
        String permissionSetLabel
    ) {
        if (String.isBlank(objectApiName) || String.isBlank(permissionSetName) || String.isBlank(permissionSetLabel)) {
            throw new IllegalArgumentException('Object API name, permission set name, and label are required.');
        }
        MetadataService.MetadataPort metadataService = new MetadataService.MetadataPort();
        metadataService.SessionHeader = new MetadataService.SessionHeader_element();
        metadataService.SessionHeader.sessionId = UserInfo.getSessionId();
        // Define PermissionSet metadata
        MetadataService.PermissionSet permissionSetMetadata = new MetadataService.PermissionSet();
        permissionSetMetadata.fullName = permissionSetName;
        permissionSetMetadata.label = permissionSetLabel; // Required!
        // Define Object Permissions using object_x
        MetadataService.PermissionSetObjectPermissions objPerm = new MetadataService.PermissionSetObjectPermissions();
        objPerm.object_x = objectApiName;
        objPerm.allowCreate = true;
        objPerm.allowRead = true;
        objPerm.allowEdit = true;
        objPerm.allowDelete = true;
        objPerm.viewAllRecords = true;
        objPerm.modifyAllRecords = true;
        permissionSetMetadata.objectPermissions =
            new MetadataService.PermissionSetObjectPermissions[] { objPerm };
        try {
            MetadataService.SaveResult[] results;
				if(!Test.isRunningTest())
                	results = metadataService.updateMetadata(new MetadataService.Metadata[] { permissionSetMetadata });
            if ((results != null && !results.isEmpty())||Test.isRunningTest()) {
                for (MetadataService.SaveResult result : results) {
                    if (!result.success) {
                        for (MetadataService.Error error : result.errors) {
                            throw new MetadataServiceException('PermissionSetUpdater -grantCrudAccessViaMetadata : Error in graning CRUD access to Object: ');
                        }
                    }
                }
            }else
            {
                throw new MetadataServiceException('PermissionSetUpdater -grantCrudAccessViaMetadata : Error in graning CRUD access to Object: ');
            }
        } catch (Exception ex) {
            throw new MetadataServiceException('PermissionSetUpdater -grantCrudAccessViaMetadata : Error in graning CRUD access to Object: ',ex);
        }
    }
}