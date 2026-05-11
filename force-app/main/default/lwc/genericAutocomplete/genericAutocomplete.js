import { LightningElement, api, wire } from 'lwc';
import searchRecords from '@salesforce/apex/GenericAutocompleteController.searchRecords';

export default class GenericAutocomplete extends LightningElement {
    @api objectApiName = 'Account';  // Default to Account
    @api searchField = 'Name';       // Default to Name
    @api label = 'Search Records';
    @api selectedRecordId;

    searchKey = '';
    results = [];
    showDropdown = false;

    // Use a wire service to call the Apex method when searchKey changes
    @wire(searchRecords, {
        objectName: '$objectApiName',
        searchField: '$searchField',
        searchKey: '$searchKey',
        additionalFields: '' // Can be configured later
    })
    wiredRecords({ data, error }) {
        if (data) {
            this.results = data.map(record => {
                // Return an object that includes the name and a subtitle (optional)
                return {
                    Id: record.Id,
                    Name: record[this.searchField],
                    subTitle: this.objectApiName
                };
            });
            this.showDropdown = true;
        } else if (error) {
            console.error('Error retrieving records: ' + JSON.stringify(error));
            this.results = [];
        }
    }

    get hasResults() {
        return this.results.length > 0;
    }

    handleSearch(event) {
        // Set the search key to the user's input and trigger the wire service
        this.searchKey = event.target.value;
    }

    handleOpenDropdown() {
        if (this.searchKey) {
            this.showDropdown = true;
        }
    }

    handleCloseDropdown() {
        // A slight delay to allow the handleSelect event to fire
        setTimeout(() => {
            this.showDropdown = false;
        }, 300);
    }

    handleSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        
        // Update the component's internal state
        this.selectedRecordId = selectedId;
        this.searchKey = selectedName;
        this.showDropdown = false;

        // Dispatch a custom event to notify the parent component of the selection
        const selectedEvent = new CustomEvent('recordselect', {
            detail: {
                recordId: selectedId,
                recordName: selectedName
            }
        });
        this.dispatchEvent(selectedEvent);
    }
}