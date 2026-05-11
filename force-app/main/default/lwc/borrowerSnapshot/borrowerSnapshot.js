import { LightningElement, api, wire } from 'lwc';
import getBorrowerSnapshot from '@salesforce/apex/mortgageAccountsHelper.getBorrowerSnapshot';
import getOppDetails from '@salesforce/apex/mortgageAccountsHelper.getOpportunitiesWithUnifiedDetails';

export default class BorrowerSnapshot extends LightningElement {
    @api recordId;

    totalActiveLoans;
    outstandingBalance;
    totalLoanOfficers;
    totalLoanAmount;
    /*
    @wire(getBorrowerSnapshot, { accountId: '$recordId' })
    wiredSnapshot({ error, data }) {
        if (data) {
            this.totalActiveLoans = data.totalActiveLoans;
            this.outstandingBalance = data.outstandingBalance;
            this.totalLoanOfficers = data.totalLoanOfficers;
            this.totalLoanAmount = data.totalLoanAmount;
        } else if (error) {
            console.error('Error retrieving snapshot:', error);
        }
    }
    */
   @wire(getOppDetails, { accountId: '$recordId' })
    wiredSnapshot({ error, data }) {
        if (data) {
            this.totalActiveLoans = data.totalActiveLoans;
            this.outstandingBalance = data.outstandingBalance;
            this.totalLoanOfficers = data.totalLoanOfficers;
            this.totalLoanAmount = data.totalLoanAmount;
        } else if (error) {
            console.error('Error retrieving snapshot:', error);
        }
    }
}