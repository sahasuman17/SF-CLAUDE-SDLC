public with sharing class mortgageAccountsHelper {
    ////for unified Account component
    public class MortgageDTO {
        @AuraEnabled public String Id;
        @AuraEnabled public String accountName;
        @AuraEnabled public String category;
        @AuraEnabled public String source;
		@AuraEnabled public Decimal revenue;
        public MortgageDTO(Mortgage_Customers__c mc) {
            Id = mc.Id;
            accountName = mc.Account_Name__c;
            category = mc.Category__c;
            source = mc.Source__c;
            revenue = mc.revenue__c;
        }
    }
	
    public class MortgageWrapper {
        @AuraEnabled public String unifiedAccountName;
        @AuraEnabled public Decimal totalLoanAmount;
        @AuraEnabled public Integer totalActiveLoans;
        @AuraEnabled public Integer noOfLoanOfficer;
        @AuraEnabled public List<MortgageDTO> mortgages;
    }

    public class OpportunityDTO {
        @AuraEnabled public String oppId;
        @AuraEnabled public String name;
        @AuraEnabled public String loanType;
        @AuraEnabled public String loanOfficer;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Decimal outstanding;
        @AuraEnabled public String source;
    }


    @AuraEnabled(cacheable = true)
    public static MortgageWrapper getUnifiedMortgageData(Id accountId) {
        if (accountId == null) return null;

        Mortgage_Customers__c recMort = [
            SELECT Unified_Id__c, unified_name__c 
            FROM Mortgage_Customers__c 
            WHERE Account_Id__c = :accountId 
            LIMIT 1
        ];

        if (recMort == null || String.isBlank(recMort.Unified_Id__c)) return null;

        List<Mortgage_Customers__c> related = [
            SELECT Id, Account_Name__c, Category__c, Source__c,revenue__c
            FROM Mortgage_Customers__c 
            WHERE Unified_Id__c = :recMort.Unified_Id__c
        ];

        MortgageWrapper result = new MortgageWrapper();
        result.unifiedAccountName = recMort.unified_name__c;
        result.mortgages = new List<MortgageDTO>();
		Decimal total=0.00;
        
        for (Mortgage_Customers__c mc : related) {
            result.mortgages.add(new MortgageDTO(mc));
            if(null!=mc.revenue__c)
            	total = total+ mc.revenue__c;            
        }
        Integer totalLoans = related.size();
        result.totalActiveLoans = totalLoans/2;
        result.totalLoanAmount = total;
        return result;
    }
	//for Opportunity Component
    @AuraEnabled(cacheable = true)
    public static List<OpportunityDTO> getOpportunitiesFromUnifiedId(Id accountId) {
        if (accountId == null) return new List<OpportunityDTO>();
    
        Mortgage_Customers__c recMort = [
            SELECT Unified_Id__c 
            FROM Mortgage_Customers__c 
            WHERE Account_Id__c = :accountId 
            LIMIT 1
        ];
     	System.debug('MortgageAcccountsHelper accountId : '+accountId);
        System.debug('MortgageAcccountsHelper UnifiedAccountId : '+recMort.Unified_Id__c);
        if (recMort == null || String.isBlank(recMort.Unified_Id__c)) return new List<OpportunityDTO>();
    
        List<Mortgage_Customers__c> lstMgCusts = [
            SELECT Account_Id__c,Source__c  
            FROM Mortgage_Customers__c 
            WHERE Unified_Id__c = :recMort.Unified_Id__c
        ];
    	Map<Id,String> mapAccSource = new Map<Id,String>();
        Set<Id> accountIds = new Set<Id>();
        for (Mortgage_Customers__c mc : lstMgCusts) {
            if (mc.Account_Id__c != null) {
                accountIds.add(mc.Account_Id__c);
                mapAccSource.put(mc.Account_Id__c,mc.Source__c);
            }
        }
    	System.debug('MortgageAcccountsHelper accountIds with the UnifAccId: '+accountIds);
        if (accountIds.isEmpty()) return new List<OpportunityDTO>();
    
        List<Opportunity> opps = [
            SELECT Id, Name, Loan_Type__c, Loan_Officer_Name__c, Amount, AccountId, Account.Name,Outstanding_Balance__c
            FROM Opportunity
            WHERE AccountId IN :accountIds
        ];
    	System.debug('MortgageAcccountsHelper accountIds with the opps: '+opps);
        List<OpportunityDTO> dtoList = new List<OpportunityDTO>();
        for (Opportunity o : opps) {
            OpportunityDTO dto = new OpportunityDTO();
            dto.oppId = o.Id;
            dto.name = o.Name;
            System.debug(o.Name);
            dto.loanType = o.Loan_Type__c;
            dto.loanOfficer = o.Loan_Officer_Name__c;
            dto.amount = o.Amount;
            dto.accountId = o.AccountId;
            dto.accountName = (o.Account != null) ? o.Account.Name : 'Unknown';
            dto.outstanding = o.Outstanding_Balance__c;
            dto.source = (mapAccSource?.get(o.AccountId)!=null)? mapAccSource?.get(o.AccountId):'Salesforce';
            dtoList.add(dto);
        }
    
        return dtoList;
    }
    public class UnifiedOpportunityWrapper {
        @AuraEnabled public String unifiedAccountId;
        @AuraEnabled public String unifiedAccountName;
        @AuraEnabled public Decimal totalLoanAmount;
        @AuraEnabled public Integer totalActiveLoans;
        @AuraEnabled public Decimal outstandingBalance;
        @AuraEnabled public Integer totalLoanOfficers;
        @AuraEnabled public List<OpportunityDTO> opportunities;

        public UnifiedOpportunityWrapper() {
            opportunities = new List<OpportunityDTO>();
        }
    }
    @AuraEnabled(cacheable=true)
    public static UnifiedOpportunityWrapper getOpportunitiesWithUnifiedDetails(Id accountId) {
        UnifiedOpportunityWrapper result = new UnifiedOpportunityWrapper();

        if (accountId == null) return result;

        // Step 1: Get Unified ID from Mortgage_Customers__c
        Mortgage_Customers__c recMort = [
            SELECT Unified_Id__c, unified_name__c 
            FROM Mortgage_Customers__c 
            WHERE Account_Id__c = :accountId 
            LIMIT 1
        ];

        if (recMort == null || String.isBlank(recMort.Unified_Id__c)) return result;

        result.unifiedAccountId = recMort.Unified_Id__c;
        result.unifiedAccountName = recMort.unified_name__c;

        // Step 2: Get all Mortgage records for this unified ID
        List<Mortgage_Customers__c> lstMgCusts = [
            SELECT Account_Id__c ,Source__c,unified_name__c,account_name__c,revenue__c,email__c,outstanding_balance__c
            FROM Mortgage_Customers__c 
            WHERE Unified_Id__c = :recMort.Unified_Id__c
        ];
        Map<String,String> mapAccSource = new Map<String,String>();
		set<Id> nonCrmAccountIds = new set<Id>();
        Set<String> accountIds = new Set<String>();
        List<Account> lstAcc = new List<Account>();
        Map<String,Id> mapAcc = new Map<String,Id>();
        Account accToCreate;
        Set<String> accNamesNotInCRM = new Set<String>();
        Set<String> allAccNames = new Set<String>();
        Decimal rev ;
        List<Opportunity> lstOppToCreate= new List<Opportunity>();
        List<OpportunityDTO> nonCrmDTOs = new List<OpportunityDTO>();
        Decimal revenueTotal =0.00;
        Decimal outstandingTotal = 0.00;
        Integer noActiveLoans = 0;
        Set<string> loanOfficerNames = new Set<string>();
        for (Mortgage_Customers__c mc : lstMgCusts) {
            noActiveLoans++;
            if (mc.Account_Id__c != null) {
                accountIds.add(mc.Account_Id__c);
				allAccNames.add(mc.account_name__c);    
                 mapAccSource.put(mc.account_name__c,mc.Source__c);
            }
            if(mc.source__c!='Salesforce')
            {                
                accNamesNotInCRM.add(mc.account_name__c);
                OpportunityDTO dtoMortgageNonCRM = new OpportunityDTO();
                //dto.oppId = o.Id;
                dtoMortgageNonCRM.loanType = 'Mortgage';
                dtoMortgageNonCRM.name = 'Property from '+mc.source__c;
                if(mc.source__c == 'Portal')
                	dtoMortgageNonCRM.loanOfficer = 'Srinivas Sriram';
                if(mc.source__c == 'LOS')
                	dtoMortgageNonCRM.loanOfficer = 'Adam Cooper';
                dtoMortgageNonCRM.amount = mc.revenue__c *0.9;                
                dtoMortgageNonCRM.accountName = (mc.account_name__c != null) ? mc.account_name__c : 'Unknown';   
                if(null!=mc.outstanding_balance__c)
                	dtoMortgageNonCRM.outstanding = mc.outstanding_balance__c *0.3;
                else
                    dtoMortgageNonCRM.outstanding = 0;
           		dtoMortgageNonCRM.source = mc.source__c;
                nonCrmDTOs.add(dtoMortgageNonCRM);
                revenueTotal = revenueTotal+ dtoMortgageNonCRM.amount;
                outstandingTotal = outstandingTotal + dtoMortgageNonCRM.outstanding;
                loanOfficerNames.add(dtoMortgageNonCRM.loanOfficer);
                OpportunityDTO dtoInsuranceNonCRM = new OpportunityDTO();
                //dto.oppId = o.Id;
                dtoInsuranceNonCRM.loanType = 'Insurance';
                dtoInsuranceNonCRM.name = ' -> Property from '+mc.source__c;
                if(mc.source__c == 'Portal')
                	dtoInsuranceNonCRM.loanOfficer = 'Srinivas Sriram';
                if(mc.source__c == 'LOS')
                	dtoInsuranceNonCRM.loanOfficer = 'Adam Cooper';
                dtoInsuranceNonCRM.amount = mc.revenue__c *0.1;                
                dtoInsuranceNonCRM.accountName = (mc.account_name__c != null) ? mc.account_name__c : 'Unknown';   
                dtoInsuranceNonCRM.outstanding = mc.outstanding_balance__c *0.3;
           		dtoInsuranceNonCRM.source = mc.source__c;
                nonCrmDTOs.add(dtoInsuranceNonCRM);
                revenueTotal = revenueTotal+ dtoInsuranceNonCRM.amount;
                outstandingTotal = outstandingTotal + dtoInsuranceNonCRM.outstanding;
                loanOfficerNames.add(dtoInsuranceNonCRM.loanOfficer);
                
            }
        }
        //System.enqueueJob(new MortgageCustomerProcessor(accNamesNotInCRM));
        
        if (accountIds.isEmpty()) return result;

        // Step 3: Query Opportunities
        List<Opportunity> opps = [
            SELECT Id, Name, Loan_Type__c, Loan_Officer_Name__c, Amount, AccountId, Account.Name,Outstanding_Balance__c
            FROM Opportunity
            WHERE Account.Name IN :allAccNames order by Name ASC,Loan_Type__c DESC
        ];
		
        for (Opportunity o : opps) {
            OpportunityDTO dto = new OpportunityDTO();
            dto.oppId = o.Id;
            dto.loanType = o.Loan_Type__c;
            if(dto.loanType.startsWith('Insurance'))
            {
                dto.name = ' -> '+o.Name;
            }
            else
            {
                dto.name = o.Name;
            }
            
            dto.loanOfficer = o.Loan_Officer_Name__c;
            dto.amount = o.Amount;
            dto.accountId = o.AccountId;
            dto.accountName = (o.Account != null) ? o.Account.Name : 'Unknown';            
            dto.outstanding = o.Outstanding_Balance__c;
            dto.source = (mapAccSource?.get(o.Account.Name)!=null)? mapAccSource?.get(o.Account.Name):'Salesforce';
            result.opportunities.add(dto);            
            revenueTotal = revenueTotal+ dto.amount;
            outstandingTotal = outstandingTotal + dto.outstanding;
            loanOfficerNames.add(dto.loanOfficer);
        }
		result.opportunities.addAll(nonCrmDTOs);
        result.totalLoanAmount = revenueTotal;
        result.outstandingBalance = outstandingTotal;
        result.totalActiveLoans = noActiveLoans;
        result.totalLoanOfficers = loanOfficerNames.size();
        return result;
    }
    //////////////////////////BorrowerSnapshot///////
    public class BorrowerSnapshotDTO {
        @AuraEnabled public Integer totalActiveLoans;
        @AuraEnabled public Decimal outstandingBalance;
        @AuraEnabled public Integer totalLoanOfficers;
        @AuraEnabled public Decimal totalLoanAmount;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static BorrowerSnapshotDTO getBorrowerSnapshot(Id accountId) {
        BorrowerSnapshotDTO dto = new BorrowerSnapshotDTO();
    
        // Step 1: Get Unified Id from current Mortgage_Customers__c record
        Mortgage_Customers__c rootRecord = [
            SELECT Unified_Id__c
            FROM Mortgage_Customers__c
            WHERE Account_Id__c = :accountId
            LIMIT 1
        ];
    
        if (rootRecord == null || String.isBlank(rootRecord.Unified_Id__c)) {
            return dto; // Return empty if no Unified Id
        }
    
        String unifiedId = rootRecord.Unified_Id__c;
    
        // Step 2: Get all Mortgage_Customers__c for this unified ID
        List<Mortgage_Customers__c> relatedRecords = [
            SELECT Account_Name__c
            FROM Mortgage_Customers__c
            WHERE Unified_Id__c = :unifiedId
        ];
    
        Set<String> accountNames = new Set<String>();
        for (Mortgage_Customers__c rec : relatedRecords) {
            if (String.isNotBlank(rec.Account_Name__c)) {
                accountNames.add(rec.Account_Name__c.trim());
            }
        }
    
        if (accountNames.isEmpty()) {
            return dto;
        }
    
        // Step 3: Query matching Account records
        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Name IN :accountNames
        ];
    
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
    
        if (accountIds.isEmpty()) {
            return dto;
        }
    
        // Step 4: Get all opportunities for those accounts
        List<Opportunity> opps = [
            SELECT Amount, Outstanding_Balance__c, Loan_Officer_Name__c
            FROM Opportunity
            WHERE AccountId IN :accountIds
        ];
    
        // Step 5: Calculate metrics
        Set<String> loanOfficers = new Set<String>();
        Decimal totalAmount = 0;
        Decimal totalOutstanding = 0;
    
        for (Opportunity opp : opps) {
            if (opp.Amount != null) totalAmount += opp.Amount;
            if (opp.Outstanding_Balance__c != null) totalOutstanding += opp.Outstanding_Balance__c;
            if (String.isNotBlank(opp.Loan_Officer_Name__c)) loanOfficers.add(opp.Loan_Officer_Name__c.trim());
        }
    	integer totalLoans = opps.size();
        dto.totalActiveLoans = totalLoans/2;
        dto.totalLoanAmount = totalAmount;
        dto.outstandingBalance = totalOutstanding;
        dto.totalLoanOfficers = loanOfficers.size();
    
        return dto;
    }
	//////////////////////get Loan data for Hierarchy 
	/**
    * @description Returns a map with key as Unified_Account_Name__c and value as related Account_Name__c list,
    *              all from Mortgage_Customers__c sharing the same Unified_Id__c as the given Account Id.
    *              Result: { 'Unified_Account_Name__c' => List<String> }
    * @author Debanjan Mukherjee
    * @created 16 July 2025
    */
        @AuraEnabled(cacheable=true)
        public static Map<String, Object> getLoanData(Id accountId) {
            Map<String, Object> result = new Map<String, Object>();
            
            if (accountId == null) {
                return result;
            }
            
            // Step 1: Get base Mortgage_Customers__c record
            Mortgage_Customers__c baseRec = [
                SELECT unified_id__c, unified_name__c
                FROM Mortgage_Customers__c
                WHERE Account_Id__c = :accountId
                LIMIT 1
            ];
            
            if (baseRec == null || String.isBlank(baseRec.unified_id__c) || String.isBlank(baseRec.unified_name__c)) {
                return result;
            }
            
            // Step 2: Get all related Account_Name__c values under the same Unified_Id__c
            List<Mortgage_Customers__c> related = [
                SELECT account_name__c,source__c
                FROM Mortgage_Customers__c
                WHERE Unified_Id__c = :baseRec.unified_id__c
            ];
            
            
            return new Map<String, Object>{
                'account' => baseRec.unified_name__c.trim(),
                'relatedAccounts' => new List<Mortgage_Customers__c>(related)
            };
            
        }



}