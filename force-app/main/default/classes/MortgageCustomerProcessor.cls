public class MortgageCustomerProcessor implements Queueable {
    private Set<string> customerNames;

    public MortgageCustomerProcessor(Set<string> customerNames) {
        this.customerNames = customerNames;
    }

    public void execute(QueueableContext context) {
        if (customerNames == null || customerNames.isEmpty()) return;

        // Step 1: Query Mortgage Customers
        Map<Id, Mortgage_Customers__c> customerMap = new Map<Id, Mortgage_Customers__c>(
            [SELECT Id, account_id__c, account_name__c, account_number__c, category__c,
                    unified_name__c, unified_id__c, revenue__c, email__c, source__c
             FROM Mortgage_Customers__c
             WHERE account_name__c IN :customerNames]
        );

        Set<String> accountNamesToCheck = new Set<String>();

        for (Mortgage_Customers__c mc : customerMap.values()) {
            if (String.isNotBlank(mc.account_name__c)) {
                accountNamesToCheck.add(mc.account_name__c);
            }
        }

        // Step 2: Query Existing Accounts
        Map<String, Account> existingAccountsByName = new Map<String, Account>();
        if (!accountNamesToCheck.isEmpty()) {
            for (Account acc : [
                SELECT Id, Name 
                FROM Account 
                WHERE Name IN :accountNamesToCheck
            ]) {
                existingAccountsByName.put(acc.Name, acc);
            }
        }
		// Step 0: Get fallback Contact
        Contact fallbackContact;
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        if (!contacts.isEmpty()) {
            fallbackContact = contacts[0];
        }

        List<Account> accountsToInsert = new List<Account>();
        Map<String, Account> newAccountsMap = new Map<String, Account>();

        // Step 3: Prepare New Accounts
        for (Mortgage_Customers__c mc : customerMap.values()) {
            String accName = mc.account_name__c?.trim();
            if (String.isNotBlank(accName) && !existingAccountsByName.containsKey(accName) && !newAccountsMap.containsKey(accName)) {
                Account accToCreate = new Account();
                accToCreate.Name = accName;
                accToCreate.email__c = mc.email__c;
                accToCreate.RecordTypeId = '012Ea000005HCMrIAO';
                accountsToInsert.add(accToCreate);
                newAccountsMap.put(accName, accToCreate);
            }
        }

        // Step 4: Insert New Accounts
        if (!accountsToInsert.isEmpty()) {
            insert accountsToInsert;
        }

        // Combine all accounts into one lookup map
        for (Account acc : accountsToInsert) {
            existingAccountsByName.put(acc.Name, acc);
        }

        List<Opportunity> lstOppToCreate = new List<Opportunity>();
		Set<String> setOpps = new Set<String>();
        // Step 5: Create Opportunities
        for (Mortgage_Customers__c mc : customerMap.values()) {
            String accName = mc.account_name__c?.trim();
            if (String.isNotBlank(accName) && existingAccountsByName.containsKey(accName)) {
                Account accRef = existingAccountsByName.get(accName);
                Decimal rev = mc.revenue__c != null ? mc.revenue__c : 600000;

                Opportunity oppMortToCreate = new Opportunity();
                oppMortToCreate.Name = 'Property Loan - Serenia Haven';
                oppMortToCreate.RecordTypeId = '012Ea000005HCQ5IAO';
                oppMortToCreate.Amount = rev;
                oppMortToCreate.StageName ='Needs Analysis';
                oppMortToCreate.AccountId = accRef.Id;
				oppMortToCreate.CloseDate = Date.today().addDays(30);
                oppMortToCreate.Loan_Officer__c = fallbackContact.Id;
                Opportunity oppInsToCreate = new Opportunity();
                oppInsToCreate.Name = 'Property Loan - Serenia Haven';
                oppInsToCreate.RecordTypeId = '012Ea000005HCQ6IAO';
                oppInsToCreate.StageName ='Needs Analysis';
                oppInsToCreate.CloseDate = Date.today().addDays(30);
                oppInsToCreate.Amount = rev*0.01;
                oppInsToCreate.AccountId = accRef.Id;
				oppInsToCreate.Loan_Officer__c = fallbackContact.Id;
                lstOppToCreate.add(oppMortToCreate);
                lstOppToCreate.add(oppInsToCreate);
                setOpps.add(oppMortToCreate.Name);
                setOpps.add(oppInsToCreate.Name);
            }
        }
		Opportunity[] lstOpps = [Select Id From Opportunity where Name in :setOpps];
        // Step 6: Insert Opportunities
        if (lstOpps.isEmpty()) {
            insert lstOppToCreate;
        }
    }
}