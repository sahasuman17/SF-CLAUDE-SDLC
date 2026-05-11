import { LightningElement, api, wire } from 'lwc';
import getOpportunitiesWithUnifiedDetails from '@salesforce/apex/mortgageAccountsHelper.getOpportunitiesWithUnifiedDetails';

export default class UnifiedOpportunityViewer extends LightningElement {
    @api recordId;
    unifiedAccountId = '';
    unifiedAccountName = '';
    opportunities = [];

    columns = [
        {
            label: 'Opportunity Name',
            fieldName: 'oppLink',
            type: 'url',
            typeAttributes: { label: { fieldName: 'name' }, target: '_blank' }
        },
        {
            label: 'Account',
            fieldName: 'accountLink',
            type: 'url',
            typeAttributes: { label: { fieldName: 'accountName' }, target: '_blank' }
        },
        { label: 'Loan Type', fieldName: 'loanType' },
        { label: 'Loan Officer', fieldName: 'loanOfficer' },
        { label: 'Amount', fieldName: 'amount', type: 'currency' },
        { label: 'Outstanding', fieldName: 'outstanding', type: 'currency' },
        //{ label: 'Source', fieldName: 'source'}
    ];

    @wire(getOpportunitiesWithUnifiedDetails, { accountId: '$recordId' })
    wiredWrapper({ error, data }) {
        if (data) {
            console.log('Unified Wrapper:', data);
            this.unifiedAccountId = data.unifiedAccountId;
            this.unifiedAccountName = data.unifiedAccountName;
            this.opportunities = data.opportunities.map(item => ({
                ...item,
                oppLink: `/lightning/r/Opportunity/${item.oppId}/view`,
                accountLink: `/lightning/r/Account/${item.accountId}/view`
            }));
        } else if (error) {
            console.error('Error fetching unified opportunity data:', error);
        }
    }
}