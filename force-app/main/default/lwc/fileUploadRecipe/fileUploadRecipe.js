import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// Import all necessary Apex methods
import getFileData from '@salesforce/apex/FileAttachmentController.getFileData';
import deleteFile from '@salesforce/apex/FileAttachmentController.deleteFile';
import setRollupFlagOnContentVersion from '@salesforce/apex/FileAttachmentController.setRollupFlagOnContentVersion'; 
import linkFilesToRecord from '@salesforce/apex/FileAttachmentController.linkFilesToRecord'; // New import for relinking files
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';

// Define the Case Status field API name
const CASE_STATUS_FIELD = 'Case.Status';

export default class FileUploadRecipe extends LightningElement {
    @api recordId;
    @track files = [];
    @track caseStatus = '';
    @track isLoading = false;
    wiredFileDataResult;

    // Define statuses where deletion is DISABLED (e.g., Case is Closed)
    DELETE_DISABLED_STATUSES = ['Closed', 'Escalated']; 

    // Helper to conditionally render the main content if a recordId is present
    get isRecordIdValid() {
        // Checks if recordId is not blank and looks like a Salesforce ID (length 15 or 18)
        return this.recordId && (this.recordId.length === 15 || this.recordId.length === 18);
    }

    // 1. Reactive Wire Call for Case Status (Only relevant when recordId is a Case)
    @wire(getRecord, { recordId: '$recordId', fields: [CASE_STATUS_FIELD] })
    wiredCase({ error, data }) {
        if (data) {
            // This runs whenever the Status field changes on the page
            this.caseStatus = data.fields.Status.value;
        } else if (error) {
            this.caseStatus = 'Unknown';
            // Suppress error log if the ID is intentionally not a Case (e.g., User ID)
            if (this.recordId && !this.recordId.startsWith('005')) {
                console.error('Error fetching Case Status. Ensure the recordId is a valid Case ID.', error);
            }
        }
    }
    
    // 2. Apex Wire Call for Files (Filter logic is handled in Apex based on ID prefix)
    @wire(getFileData, { recordId: '$recordId' })
    wiredFiles(result) {
        this.wiredFileDataResult = result;
        if (result.data) {
            this.files = result.data.files;
            
            const contentDocumentIds = this.files.map(f => f.contentDocumentId);
            console.log('Attached ContentDocument IDs:', contentDocumentIds);

        } else if (result.error) {
            this.showToast('Error', result.error.body.message, 'error');
            console.error('Error fetching file data:', result.error);
        }
    }

    get isDeleteDisabled() {
        // Return true if the current case status is in the disabled list
        return this.DELETE_DISABLED_STATUSES.includes(this.caseStatus);
    }
    
    get deleteTooltip() {
        return this.isDeleteDisabled 
            ? 'Files cannot be deleted when the Case Status is ' + this.caseStatus 
            : 'Delete this file';
    }

    // PUBLIC METHOD to be called from the parent component
    /**
     * Relinks files currently attached to the component's recordId (Source ID, typically User ID)
     * to a new targetRecordId (e.g., Case, Account, Contact).
     * @param {string} targetRecordId - The new record ID to link files to.
     * @returns {Promise<boolean>} - True if successful, false if not.
     */
    @api 
    relinkUploadedFiles(targetRecordId) {
        if (!this.files.length) {
            this.showToast('Info', 'No files to link.', 'info');
            return Promise.resolve(true);
        }
        
        if (!targetRecordId) {
            this.showToast('Error', 'Target Record ID is required for relinking.', 'error');
            return Promise.resolve(false);
        }

        this.isLoading = true;
        
        // 1. Get the list of ContentDocument IDs currently attached to the source recordId (User ID)
        const contentDocumentIds = this.files.map(file => file.contentDocumentId);

        // 2. Call Apex to relink files from the current recordId (Source) to the targetRecordId
        return linkFilesToRecord({ 
            sourceRecordId: this.recordId, 
            targetRecordId: targetRecordId, 
            contentDocumentIds: contentDocumentIds 
        })
        .then(() => {
            this.showToast('Success', `${this.files.length} files successfully linked to the new record.`, 'success');
            // Refresh the data list. If called from the source (User) page, the list should now empty.
            return refreshApex(this.wiredFileDataResult);
        })
        .catch(error => {
            this.showToast('Error', 'Relinking failed: ' + error.body.message, 'error');
            console.error('Relinking Error:', error);
            return Promise.resolve(false);
        })
        .finally(() => {
            this.isLoading = false;
        });
    }


    // Handles the file upload completion and updates the custom field
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        
        if (uploadedFiles.length > 0) {
            // Extract ContentDocument IDs from the upload event detail
            const contentDocumentIds = uploadedFiles.map(file => file.documentId);

            // 1. Call Apex to update the custom field (Exclude_From_File_Rollup__c = TRUE)
            setRollupFlagOnContentVersion({ contentDocumentIds: contentDocumentIds })
                .then(() => {
                    this.showToast('Success', `${uploadedFiles.length} files uploaded and marked for exclusion successfully!`, 'success');
                    
                    // 2. Refresh the component data to show the new, filtered files
                    return refreshApex(this.wiredFileDataResult);
                })
                .catch(error => {
                    this.showToast('Error', 'File upload failed or failed to set rollup flag: ' + error.body.message, 'error');
                    console.error('Rollup Flag Update Error:', error);
                    refreshApex(this.wiredFileDataResult); 
                });
        }
    }

    // Handles file deletion
    handleDeleteFile(event) {
        if (this.isDeleteDisabled) {
            this.showToast('Error', this.deleteTooltip, 'error');
            return;
        }

        const documentId = event.currentTarget.dataset.id;
        this.isLoading = true;

        deleteFile({ contentDocumentId: documentId, recordId: this.recordId })
            .then(() => {
                this.showToast('Success', 'File deleted successfully.', 'success');
                // Refresh the data list
                return refreshApex(this.wiredFileDataResult);
            })
            .catch(error => {
                this.showToast('Error', 'Could not delete file: ' + error.body.message, 'error');
                console.error('Delete error:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Utility function for showing toast notifications
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}