import { LightningElement, api } from 'lwc';

export default class FileAttachmentContainer extends LightningElement {
    // This decorator makes the recordId property public, allowing Salesforce 
    // to automatically inject the current record's ID when placed on a record page.
    @api recordId='005dN000000QH21QAG';
    @api targetRecordId = '500dN0000015kovQAA';
 async handleRelinkClick() {
        // 1. Get a reference to the child component using lwc:ref="uploaderRef"
        const childUploader = this.template.querySelector('c-file-upload-recipe');

        if (!childUploader) {
            this.showToast('Error', 'File Uploader component not found.', 'error');
            return;
        }

        if (!this.targetRecordId) {
            this.showToast('Error', 'Please enter a Target Record ID.', 'error');
            return;
        }
        
        // Disable the button and show loading while the relinking process runs
        this.isLoading = true;

        try {
            // 2. Call the public method defined in the child component (fileUploadRecipe.js)
            const success = await childUploader.relinkUploadedFiles(this.targetRecordId);
            
            // The method already shows a toast, but you can add custom parent logic here
            if (success) {
                console.log('File relinking process completed successfully.');
            } else {
                // If the promise resolves to false, it means relinking failed in Apex.
                console.error('File relinking process failed.');
            }
        } catch (error) {
            // Catches any unexpected JS error during the method call
            this.showToast('Fatal Error', 'An unexpected error occurred during relinking.', 'error');
            console.error('Unexpected Error:', error);
        } finally {
            this.isLoading = false;
        }
    }

    // The recordId received by this component is automatically passed down
    // to the child component (c-file-upload-recipe) via the HTML template.
}