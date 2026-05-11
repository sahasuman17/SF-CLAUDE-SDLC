import { LightningElement, api, track, wire } from 'lwc';
import getLoanData from '@salesforce/apex/mortgageAccountsHelper.getLoanData';

export default class LoanHierarchy extends LightningElement {
    @api recordId; // Pass in Account ID
    accountName;
    @track relatedAccounts = [];
    @track selectedRecord;
 handleAccountSelect(event) {
        this.selectedRecord = event.detail; 
        // event.detail should contain { Id, Name } or whatever you send from child
        console.log('Selected record from autocomplete: ', this.selectedRecord);
    }
    @wire(getLoanData, { accountId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            console.log(data);
            this.accountName = data.account;
            this.relatedAccounts = data.relatedAccounts;
        } else if (error) {
            console.error('Error fetching loan data:', error);
        }
    }
}