import { LightningElement, api, wire } from 'lwc';
import getUnifiedMortgageData from '@salesforce/apex/mortgageAccountsHelper.getUnifiedMortgageData';

export default class MortgageAccounts extends LightningElement {
    @api recordId;
    unifiedAccountName = '';
    lstMortgages = [];
    showDetails = false;

    // Must match DTO field names in Apex (not __c names)
    columns = [
        { label: 'Account Name', fieldName: 'accountName' },
        { label: 'Category', fieldName: 'category' },
        { label: 'Source', fieldName: 'source' }
    ];

    @wire(getUnifiedMortgageData, { accountId: '$recordId' })
    wiredMortgageData({ error, data }) {
        if (data) {
            this.unifiedAccountName = data.unifiedAccountName;
            this.lstMortgages = data.mortgages;
        } else if (error) {
            console.error('Error fetching data:', error);
        }
    }

    toggleDetails() {
        this.showDetails = !this.showDetails;
    }

    get hasData() {
        return this.lstMortgages && this.lstMortgages.length > 0;
    }
}