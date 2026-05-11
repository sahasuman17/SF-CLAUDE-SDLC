/**
 * @author      Debanjan Mukherjee
 * @created     14 July 2025
 * @description Parameterized utility to create:
 *              - Borrower and Individual Accounts
 *              - Mortgage and Insurance Opportunities (Closed Won, with Amount)
 *              - Loan Officer Contact assigned via Loan_Officer__c
 * Caller Script - SampleDataCreator.createSampleData('Nikhil Sharma', 'Palm Grove Residency', 'Anjali Rao');
 */
public class SampleDataCreator {

    /**
     * Creates sample records:
     * - Two Accounts with same name and email but different RecordTypes
     * - Two Opportunities with same name, different RecordTypes, marked as Closed Won with amount
     * - One Contact as Loan Officer assigned to both Opportunities via Loan_Officer__c
     *
     * @param accountName   Name for both Borrower and Individual Accounts
     * @param propertyName  Name for both Mortgage and Insurance Opportunities
     * @param contactName   LastName for Loan Officer Contact
     */
    public static void createSampleData(String accountName, String propertyName, String contactName, String email) {
        if (String.isBlank(accountName) || String.isBlank(propertyName) || String.isBlank(contactName)) {
            throw new IllegalArgumentException('All parameters must be non-blank.');
        }

        // Step 1: Fetch RecordType IDs
        Map<String, Id> accountRTs = new Map<String, Id>();
        Map<String, Id> oppRTs = new Map<String, Id>();
        Map<String, Id> contactRTs = new Map<String, Id>();

        for (RecordType rt : [
            SELECT Id, DeveloperName, SObjectType 
            FROM RecordType 
            WHERE SObjectType IN ('Account', 'Opportunity', 'Contact')
        ]) {
            if (rt.SObjectType == 'Account')      accountRTs.put(rt.DeveloperName, rt.Id);
            else if (rt.SObjectType == 'Opportunity') oppRTs.put(rt.DeveloperName, rt.Id);
            else if (rt.SObjectType == 'Contact')     contactRTs.put(rt.DeveloperName, rt.Id);
        }

        // Step 2: Create Loan Officer Contact
        Contact loanOfficer = new Contact(
            LastName = contactName,
            RecordTypeId = contactRTs.get('Loan_Officer')
        );
        insert loanOfficer;

        // Step 3: Create Accounts
        //String email = accountName.toLowerCase().replace(' ', '.') + '@example.com';

        Account borrower = new Account(
            Name = accountName,
            Email__c = email,
            RecordTypeId = accountRTs.get('Borrower')
        );
        /*
        Account individual = new Account(
            Name = accountName,
            Email__c = email,
            RecordTypeId = accountRTs.get('Individual')
        );
		*/
        insert new List<Account>{ borrower};//, individual };

        // Step 4: Create Opportunities (Closed Won, with Amount)
        Opportunity mortgageOpp = new Opportunity(
            Name = propertyName,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 500000,
            RecordTypeId = oppRTs.get('Mortgage'),
            AccountId = borrower.Id,
            Loan_Officer__c = loanOfficer.Id
        );

        Opportunity insuranceOpp = new Opportunity(
            Name = propertyName,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 20000,
            RecordTypeId = oppRTs.get('Insurance'),
            //AccountId = individual.Id,
            AccountId = borrower.Id,
            Loan_Officer__c = loanOfficer.Id
        );

        insert new List<Opportunity>{ mortgageOpp, insuranceOpp };

        System.debug('Sample data created for: ' + accountName + ', ' + propertyName + ', ' + contactName);
    }
}