/**
 * @description Apex controller for the caseCreate LWC component (MP-8).
 *              Provides three AuraEnabled methods to support the Product Information
 *              section of the Create a Support Case screen for Parts Technical Help.
 *
 *              Methods:
 *                - findAssetBySerial  : fetches Asset data by serial number
 *                - getPartDescription : fetches Part_Description__c for a Part__c record
 *                - saveCaseAsDraft    : inserts Case with Status = Draft, returns CaseNumber
 *
 * @author      Suman Saha
 * @story       MP-8
 */
public with sharing class CaseCreateController {

    // ─── Find Asset by Serial Number ───────────────────────────────────────────

    /**
     * @description Queries the Asset object by SerialNumber and returns a wrapper
     *              containing all product-information fields required by the UI.
     *              Returns null when no matching Asset is found.
     *
     * @param  serialNumber  The serial number entered by the user.
     * @return               AssetWrapper with asset details, or null.
     */
    @AuraEnabled(cacheable=true)
    public static AssetWrapper findAssetBySerial(String serialNumber) {
        if (String.isBlank(serialNumber)) {
            return null;
        }

        List<Asset> assets = [
            SELECT Id,
                   Engine_Serial_Number__c,
                   Machine_Type__c,
                   Series__c,
                   Model_Name__c,
                   Model_Name__r.Name,
                   Model_Name__r.Brand_Name__r.Name,
                   Unit_of_Measure__c,
                   Usage__c
            FROM   Asset
            WHERE  SerialNumber = :serialNumber
            WITH   USER_MODE
            LIMIT  1
        ];

        if (assets.isEmpty()) {
            return null;
        }

        Asset asset         = assets[0];
        AssetWrapper info   = new AssetWrapper();
        info.assetId        = asset.Id;
        info.brand          = asset.Model_Name__r?.Brand_Name__r?.Name;
        info.machineType    = asset.Machine_Type__c;
        info.series         = asset.Series__c;
        info.modelNumber    = asset.Model_Name__r?.Name;
        info.unitOfMeasure  = asset.Unit_of_Measure__c;
        info.machineUsage   = asset.Usage__c != null
                                ? String.valueOf(asset.Usage__c.intValue())
                                : null;
        info.usageAvailable = (asset.Usage__c != null);
        info.engineSerial   = asset.Engine_Serial_Number__c;
        return info;
    }

    // ─── Get Part Description ──────────────────────────────────────────────────

    /**
     * @description Returns the Part_Description__c value for a given Part__c Id.
     *              Returns null when the Part record is not found.
     *
     * @param  partId  The Salesforce Id of the Part__c record.
     * @return         Part description string or null.
     */
    @AuraEnabled(cacheable=true)
    public static String getPartDescription(Id partId) {
        if (partId == null) {
            return null;
        }

        List<Part__c> parts = [
            SELECT Id, Part_Description__c
            FROM   Part__c
            WHERE  Id = :partId
            WITH   USER_MODE
            LIMIT  1
        ];

        return parts.isEmpty() ? null : parts[0].Part_Description__c;
    }

    // ─── Save Case as Draft ────────────────────────────────────────────────────

    /**
     * @description Sets Status = 'Draft' on the provided Case sObject and inserts it.
     *              The LWC passes only the 11 Product Information fields; this method
     *              does not set any additional fields. After insert, re-queries
     *              CaseNumber and Status to return in SaveResult.
     *
     * @param  caseRecord  A Case sObject pre-populated with Product Information fields.
     * @return             SaveResult containing caseId, caseNumber, and status.
     */
    @AuraEnabled
    public static SaveResult saveCaseAsDraft(Case caseRecord) {
        if (caseRecord == null) {
            throw new AuraHandledException('Case record cannot be null.');
        }

        caseRecord.Status = 'Draft';

        try {
            insert caseRecord;
        } catch (DmlException e) {
            throw new AuraHandledException('Failed to save case: ' + e.getDmlMessage(0));
        }

        Case saved = [
            SELECT CaseNumber, Status
            FROM   Case
            WHERE  Id = :caseRecord.Id
            WITH   USER_MODE
            LIMIT  1
        ];

        SaveResult result   = new SaveResult();
        result.caseId       = caseRecord.Id;
        result.caseNumber   = saved.CaseNumber;
        result.status       = saved.Status;
        return result;
    }

    // ─── Inner Wrapper Classes ─────────────────────────────────────────────────

    /**
     * @description Wrapper returned by findAssetBySerial containing all
     *              product information fields needed by the UI.
     */
    public class AssetWrapper {
        @AuraEnabled public Id      assetId;          // Asset.Id → Case.AssetId
        @AuraEnabled public String  brand;            // Model_Name__r.Brand_Name__r.Name
        @AuraEnabled public String  machineType;      // Machine_Type__c (formula)
        @AuraEnabled public String  series;           // Series__c (formula)
        @AuraEnabled public String  modelNumber;      // Model_Name__r.Name
        @AuraEnabled public String  unitOfMeasure;    // Unit_of_Measure__c
        @AuraEnabled public String  machineUsage;     // Usage__c as integer string, or null
        @AuraEnabled public Boolean usageAvailable;   // true when Usage__c has a value
        @AuraEnabled public String  engineSerial;     // Engine_Serial_Number__c (UI only)
    }

    /**
     * @description Wrapper returned by saveCaseAsDraft after successful insert.
     */
    public class SaveResult {
        @AuraEnabled public Id     caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String status;
    }
}
