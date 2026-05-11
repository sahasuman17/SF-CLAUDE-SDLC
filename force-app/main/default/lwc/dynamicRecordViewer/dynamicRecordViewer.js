import { LightningElement, track } from 'lwc';
import fetchRecordsWithMetadata from '@salesforce/apex/DynamicDataFetcher.fetchRecordsWithMetadata';
import getCalculatedInsights from '@salesforce/apex/DynamicDataFetcher.getCalculatedInsights';

export default class DynamicRecordViewer extends LightningElement {
    @track options = [];
    @track selectedObjectName = '';
    @track searchTerm = '';
    @track searchField = '';
    @track sortField = '';
    @track isLoading = false;
    @track message = '';
    @track records = [];
    @track columns = [];
    @track error = '';
    @track hasRecords = false;

    pageSize = 10;
    currentOffset = 0;
    totalCount = 0;
    handleSearchKey(event) {
        this.searchField = event.detail.value;
        // You can now use `this.selectedField` to show related field values in a datatable or elsewhere
    }
    handleSortKey(event) {
        // You can now use `this.selectedField` to show related field values in a datatable or elsewhere
        this.sortField = event.detail.value;
        this.currentOffset = 0;
        this.fetchRecords();
    }
    connectedCallback() {
        getCalculatedInsights()
            .then((data) => {
                this.options = [
                    { label: '-- Select --', value: '' },
                    ...data.map((ci) => ({ label: ci.label, value: ci.value }))
                ];
            })
            .catch((err) => {
                this.error = err?.body?.message || err.message || 'Failed to load options';
            });
    }

    handleObjectChange(event) {
        this.selectedObjectName = event.detail.value;
        this.currentOffset = 0;
        if (this.selectedObjectName) {
            this.fetchRecords();
        } else {
            this.records = [];
            this.columns = [];
            this.message = '';
            this.totalCount = 0;
            this.hasRecords = false;
        }
    }

    handleSearchChange(event) {
        const term = event.target.value;
        // Only search when input is longer than 2 characters
        if (term && term.length > 2) {
            // Case 1: User typed >2 characters → perform search
            this.searchTerm = term;
            this.currentOffset = 0;
            this.fetchRecords();
        } else if (!term) {
            // Case 2: Input is empty → reset to all records
            if (this.searchTerm !== '') {
                this.searchTerm = '';
                this.currentOffset = 0;
                this.fetchRecords(); // reload unfiltered
            }
        }
    }

    fetchRecords() {
        if (!this.selectedObjectName) return;

        this.isLoading = true;
        this.records = [];
        this.columns = [];
        this.error = '';
        this.message = '';

        fetchRecordsWithMetadata({
            inputObjectName: this.selectedObjectName,
            searchField: this.searchField,
            sortField: this.sortField,
            searchTerm: this.searchTerm,
            pageSize: this.pageSize,
            offset: this.currentOffset
        })
            .then((result) => {
                this.hasRecords = result.hasRecords;
                this.message = result.message;
                this.totalCount = result.totalCount;

                // Prepare columns (convert Id -> View link)
                this.columns = (result.columns || []).map(col => {
                    if (col.fieldName === 'Id') {
                        return {
                            label: 'Record',
                            fieldName: 'recordLink',
                            type: 'url',
                            typeAttributes: {
                                label: 'View',
                                target: '_blank'
                            }
                        };
                    }
                    return {
                        label: col.label,
                        fieldName: col.fieldName,
                        value: col.fieldName
                    };
                });

                // Inject recordLink
                this.records = (result.data || []).map(row => ({
                    ...row,
                    recordLink: '/' + row.Id
                }));
                if (!this.searchField) {
                    const defaultCol = this.columns.find(col => col.label === 'Unified Name');
                    if (defaultCol) {
                        this.searchField = defaultCol.value;
                    } else if (this.columns.length > 0) {
                        this.searchField = this.columns[0].value;
                    }
                }
                if (!this.sortField) {
                    let defaultSort =[];
                    defaultSort = this.columns.find(col => col.label == 'Unified Name');
                    if(!defaultSort)
                    {
                        defaultSort = this.columns.find(col => col.label.includes('Name'));
                    }
                    if (defaultSort) {
                        this.sortField = defaultSort.value;
                    } else if (this.columns.length > 0) {
                        this.sortField = this.columns[0].value;
                    }
                }
            })
            .catch((err) => {
                this.error = err?.body?.message || err.message || 'Unknown error occurred';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handlePrevious() {
        if (this.currentOffset >= this.pageSize) {
            this.currentOffset -= this.pageSize;
            this.fetchRecords();
        }
    }

    handleNext() {
        if (this.currentOffset + this.pageSize < this.totalCount) {
            this.currentOffset += this.pageSize;
            this.fetchRecords();
        }
    }

    get currentPage() {
        return Math.floor(this.currentOffset / this.pageSize) + 1;
    }

    get totalPages() {
        return Math.ceil(this.totalCount / this.pageSize);
    }

    get isPreviousDisabled() {
        return this.currentOffset === 0;
    }

    get isNextDisabled() {
        return this.currentOffset + this.pageSize >= this.totalCount;
    }
}