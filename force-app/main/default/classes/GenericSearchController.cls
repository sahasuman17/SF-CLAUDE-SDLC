/**
* @File Name : GenericSearchController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : 
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | Date |   | Initial Version
**/

public with sharing class GenericSearchController {
    @AuraEnabled(cacheable=true)
    public static List<sObject> searchRecords(String objectApi, String fieldApi, String keyword) {
        if (String.isBlank(objectApi) || String.isBlank(fieldApi) || String.isBlank(keyword)) {
            return new List<sObject>();
        }

        String soql = 'SELECT Id, ' + fieldApi + 
                      ' FROM ' + objectApi + 
                      ' WHERE ' + fieldApi + 
                      ' LIKE :(\'%' + keyword + '%\') ' +
                      ' LIMIT 10';

        return Database.query(soql);
    }
}