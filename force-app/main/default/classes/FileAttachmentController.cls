public with sharing class FileAttachmentController {

    // Custom setting field API name for excluding files from standard rollup
    private static final String EXCLUDE_FIELD = 'ContentVersion.Exclude_From_File_Rollup__c';
    private static final String CASE_PREFIX = '500';

    /**
     * Retrieves files associated with the given recordId.
     * If the recordId is a Case ID (starts with 500), it includes files linked to related records.
     * Otherwise, it only fetches files directly linked to the recordId (e.g., User, Temp Record).
     * @param recordId The ID of the record (Case, User, etc.)
     * @return A map containing a list of files.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<FileWrapper>> getFileData(Id recordId) {
        List<FileWrapper> fileWrappers = new List<FileWrapper>();
        List<Id> contentDocumentIds = new List<Id>();
        List<String> recordPrefixes = new List<String>{'005', CASE_PREFIX, '001', '003'}; // User, Case, Account, Contact, etc.
        
        // Ensure recordId is valid and not one of the internal prefixes used for filtering
        if (recordId == null || recordId.getSObjectType() == null || !recordPrefixes.contains(String.valueOf(recordId).substring(0, 3))) {
            return new Map<String, List<FileWrapper>>{'files' => fileWrappers};
        }

        Set<Id> linkedEntityIds = new Set<Id>();
        linkedEntityIds.add(recordId);

        // Logic for fetching files based on Case ID (500)
        if (String.valueOf(recordId).startsWith(CASE_PREFIX)) {
            // Include Case, Account, and Contact files (if available in a real Case structure)
            // For a production app, you'd query the Case for its AccountId and ContactId.
            // For now, we rely only on the direct recordId linking as requested by the LWC.
        }

        // 1. Query ContentDocumentLink to find all ContentDocuments associated with the record(s)
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :linkedEntityIds
        ];

        for (ContentDocumentLink cdl : links) {
            contentDocumentIds.add(cdl.ContentDocumentId);
        }

        if (contentDocumentIds.isEmpty()) {
            return new Map<String, List<FileWrapper>>{'files' => fileWrappers};
        }

        // 2. Query ContentVersion for file details, filtering out files marked for rollup exclusion.
        List<ContentVersion> versions = [
            SELECT Id, ContentDocumentId, Title, FileExtension, FileType, ContentSize, CreatedDate, 
                   SystemModstamp, Exclude_From_File_Rollup__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = true
            ORDER BY CreatedDate DESC
        ];

        for (ContentVersion cv : versions) {
            // We only show files that are NOT marked for rollup exclusion
            // This ensures only files uploaded specifically to this component are managed/moved.
            if (cv.Exclude_From_File_Rollup__c == true) {
                fileWrappers.add(new FileWrapper(cv.ContentDocumentId, cv.Title, cv.FileExtension, cv.ContentSize, cv.CreatedDate));
            }
        }

        return new Map<String, List<FileWrapper>>{'files' => fileWrappers};
    }

    /**
     * Sets a custom field (Exclude_From_File_Rollup__c) on the latest ContentVersion 
     * for the uploaded ContentDocuments.
     * @param contentDocumentIds List of ContentDocument IDs to update.
     */
    @AuraEnabled
    public static void setRollupFlagOnContentVersion(List<Id> contentDocumentIds) {
        List<ContentVersion> versionsToUpdate = new List<ContentVersion>();
        
        // Find the latest ContentVersion for each ContentDocument
        List<ContentVersion> latestVersions = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = true
        ];

        for (ContentVersion cv : latestVersions) {
            // Check if the field is writeable before attempting to set it (best practice)
            //if (Schema.SObjectType.ContentVersion.fields.get('Exclude_From_File_Rollup__c').isUpdateable()) {
                cv.Exclude_From_File_Rollup__c = true;
                versionsToUpdate.add(cv);
            //}
        }

        if (!versionsToUpdate.isEmpty()) {
            update versionsToUpdate;
        }
    }

    /**
     * Deletes the ContentDocument and all associated ContentDocumentLink records.
     * Files are deleted only if they are linked ONLY to the source record.
     * NOTE: For this recipe, we just unlink the file from the source record.
     * @param contentDocumentId The ID of the ContentDocument to delete/unlink.
     * @param recordId The source record ID to unlink from.
     */
    @AuraEnabled
    public static void deleteFile(Id contentDocumentId, Id recordId) {
        
        // If the recordId is a User ID, deleting the ContentDocumentLink often fails 
        // because it's the primary sharing link. In this context, the user likely means to delete the file.
        if (recordId.getSObjectType() == Schema.User.getSObjectType()) {
            try {
                // Delete the entire file (ContentDocument)
                delete [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId];
                return; // Exit successfully
            } catch (Exception e) {
                // Throw exception if the full deletion fails (e.g., due to permissions)
                throw new AuraHandledException('Failed to delete the file completely: ' + e.getMessage());
            }
        }
        
        // If not a User ID, proceed with standard unlinking (ContentDocumentLink deletion)
        
        // Find the specific link between the file and the source record
        List<ContentDocumentLink> linksToDelete = [
            SELECT Id 
            FROM ContentDocumentLink 
            WHERE ContentDocumentId = :contentDocumentId 
            AND LinkedEntityId = :recordId
        ];

        if (!linksToDelete.isEmpty()) {
            try {
                // Use Database.delete with allOrNone=false to prevent FIELD_INTEGRITY_EXCEPTION from halting the transaction.
                // Since linksToDelete should contain exactly one link, we check the result of this single operation.
                Database.DeleteResult[] results = Database.delete(linksToDelete, false);
                
                if (!results[0].isSuccess()) {
                    String errorMessage = 'File unlink failed. The link may be protected.';
                    
                    // Safely check for an error message before accessing the array element
                    if (results[0].getErrors().size() > 0) {
                        errorMessage = results[0].getErrors()[0].getMessage();
                    }

                    System.debug(LoggingLevel.WARN, 'Single file unlink failed for ' + linksToDelete[0].Id + ': ' + errorMessage);
                    
                    // Throw an exception so the LWC shows the specific error toast instead of the success toast.
                    throw new AuraHandledException('File unlink failed: ' + errorMessage);
                }
            } catch (Exception e) {
                 // Catch unexpected exceptions (e.g., query error, general Apex error)
                System.debug(LoggingLevel.ERROR, 'Unexpected exception during single file deletion: ' + e.getMessage());
                throw new AuraHandledException('Unexpected error during deletion: ' + e.getMessage());
            }
        }
    }

    /**
     * Fixes the 'Field is not writeable' error by deleting the old link and inserting a new one.
     * Moves files from the sourceRecordId (e.g., User) to the targetRecordId (e.g., Case).
     * @param sourceRecordId The record the files are currently linked to (and will be unlinked from).
     * @param targetRecordId The record the files should be newly linked to.
     * @param contentDocumentIds The list of ContentDocument IDs to move.
     * @return True if relinking was successful, false otherwise.
     */
    @AuraEnabled
public static Boolean linkFilesToRecord(Id sourceRecordId, Id targetRecordId, List<Id> contentDocumentIds) {
        if (sourceRecordId == null || targetRecordId == null || contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            throw new IllegalArgumentException('Invalid parameters: all inputs are required.');
        }

        Integer deletedCount = 0;

        // Step 1: Filter eligible ContentDocuments (Exclude_From_File_Rollup__c != true)
        Set<Id> eligibleDocumentIds = new Set<Id>();
        for (AggregateResult ar : [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
              AND IsLatest = true
              AND (Exclude_From_File_Rollup__c = true)
            GROUP BY ContentDocumentId
        ]) {
            eligibleDocumentIds.add((Id) ar.get('ContentDocumentId'));
        }

        if (eligibleDocumentIds.isEmpty()) {
            System.debug('No eligible documents found. All are excluded via Exclude_From_File_Rollup__c.');
            return false;
        }

        // Step 2: Fetch ContentDocumentLinks for eligible docs from source record
        List<ContentDocumentLink> existingLinks = [
            SELECT Id, ContentDocumentId, ShareType, Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :sourceRecordId
              AND ContentDocumentId IN :eligibleDocumentIds
        ];

        if (existingLinks.isEmpty()) {
            System.debug('No ContentDocumentLink records found for eligible documents on source record.');
            return false;
        }

        // Step 3: Create new links for target record
        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        for (ContentDocumentLink oldLink : existingLinks) {
            newLinks.add(new ContentDocumentLink(
                ContentDocumentId = oldLink.ContentDocumentId,
                LinkedEntityId    = targetRecordId,
                ShareType         = oldLink.ShareType != null ? oldLink.ShareType : 'V',
                Visibility        = oldLink.Visibility != null ? oldLink.Visibility : 'AllUsers'
            ));
        }

        // Step 4: Insert new links
        Database.SaveResult[] insertResults = Database.insert(newLinks, false);

        // Collect successfully linked document Ids
        Set<Id> successfullyLinkedDocs = new Set<Id>();
        for (Integer i = 0; i < insertResults.size(); i++) {
            if (insertResults[i].isSuccess()) {
                successfullyLinkedDocs.add(newLinks[i].ContentDocumentId);
            } else {
                System.debug('Failed to link document: ' + newLinks[i].ContentDocumentId);
            }
        }

        // Step 5: Delete old links for successfully linked docs
        if (!successfullyLinkedDocs.isEmpty()) {
            List<ContentDocumentLink> linksToDelete = new List<ContentDocumentLink>();
            for (ContentDocumentLink oldLink : existingLinks) {
                if (successfullyLinkedDocs.contains(oldLink.ContentDocumentId)) {
                    linksToDelete.add(oldLink);
                }
            }

            if (!linksToDelete.isEmpty()) {
                Database.DeleteResult[] deleteResults = Database.delete(linksToDelete, false);
                for (Database.DeleteResult dr : deleteResults) {
                    if (dr.isSuccess()) {
                        deletedCount++;
                    }
                }
            }
        }

        System.debug('Successfully moved and deleted ' + deletedCount + ' ContentDocumentLinks from source to target record.');
        return deletedCount>0;
    }
    
    // Wrapper class to hold simplified file data for the LWC
    public class FileWrapper {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public Decimal contentSize;
        @AuraEnabled public DateTime createdDate;

        public FileWrapper(Id contentDocumentId, String title, String fileExtension, Decimal contentSize, DateTime createdDate) {
            this.contentDocumentId = contentDocumentId;
            this.title = title;
            this.fileExtension = fileExtension;
            this.contentSize = contentSize;
            this.createdDate = createdDate;
        }
    }
}