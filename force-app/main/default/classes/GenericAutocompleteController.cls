/**
* @File Name : GenericAutocompleteController.cls
* @Description :
* @Author :
* @Last Modified By : Anmol
* @Last Modified On : Date
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | Date |   | Initial Version
**/

public with sharing class GenericAutocompleteController {

    @AuraEnabled(cacheable=true)
    public static List<sObject> searchRecords(String objectName, String searchField, String searchKey, String additionalFields) {
        String query = '';
        String soql = 'SELECT Id, ' + searchField;

        // Add additional fields to the query if provided
        if (String.isNotBlank(additionalFields)) {
            soql += ', ' + additionalFields;
        }
        
        // Finalize the query with the WHERE and LIMIT clauses
        soql += ' FROM ' + objectName + ' WHERE ' + searchField + ' LIKE \'%' + String.escapeSingleQuotes(searchKey) + '%\' LIMIT 10';
        
        // Execute the dynamic SOQL query and return the results
        return Database.query(soql);
    }
}