public with sharing class CaseCreateController {

    // ─── Inner Classes ───────────────────────────────────────────────────────

    public class AssetWrapper {
        @AuraEnabled public Id      assetId;
        @AuraEnabled public String  brand;
        @AuraEnabled public String  machineType;
        @AuraEnabled public String  series;
        @AuraEnabled public String  modelNumber;
        @AuraEnabled public String  unitOfMeasure;
        @AuraEnabled public String  machineUsage;
        @AuraEnabled public Boolean usageAvailable;
        @AuraEnabled public String  engineSerial;
    }

    public class SaveResult {
        @AuraEnabled public Id     caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String status;
    }

    // ─── Methods ─────────────────────────────────────────────────────────────

    /**
     * Finds an Asset by its serial number and returns product information
     * fields needed to auto-populate the Product Information section.
     * Returns null if no matching Asset is found (LWC handles null gracefully).
     *
     * @param serialNumber  The serial number entered by the user
     * @return              AssetWrapper populated from Asset fields, or null
     */
    @AuraEnabled
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
            LIMIT  1
        ];

        if (assets.isEmpty()) {
            return null;
        }

        Asset asset       = assets[0];
        AssetWrapper info = new AssetWrapper();
        info.assetId        = asset.Id;
        info.brand          = asset.Model_Name__r?.Brand_Name__r?.Name;
        info.machineType    = asset.Machine_Type__c;
        info.series         = asset.Series__c;
        info.modelNumber    = asset.Model_Name__r?.Name;
        info.unitOfMeasure  = asset.Unit_of_Measure__c;
        info.machineUsage   = asset.Usage__c != null
                              ? String.valueOf(asset.Usage__c.intValue()) : null;
        info.usageAvailable = asset.Usage__c != null;
        info.engineSerial   = asset.Engine_Serial_Number__c;
        return info;
    }

    /**
     * Returns the Part Description for a given Part__c record Id.
     * Returns null if the Part is not found (LWC clears the field).
     *
     * @param partId  The Id of the Part__c record selected in the picker
     * @return        Part_Description__c value or null
     */
    @AuraEnabled
    public static String getPartDescription(Id partId) {
        if (partId == null) {
            return null;
        }

        List<Part__c> parts = [
            SELECT Id, Part_Description__c
            FROM   Part__c
            WHERE  Id = :partId
            LIMIT  1
        ];

        return parts.isEmpty() ? null : parts[0].Part_Description__c;
    }

    /**
     * Upserts a Case as Draft with only Product Information fields.
     * The LWC builds the Case sObject with the 11 product fields and passes
     * it here. Status is always forced to 'Draft' server-side.
     * Uses upsert so subsequent saves on the same record update, not insert.
     *
     * @param caseRecord  Case sObject built by LWC (11 product fields + optional Id)
     * @return            SaveResult containing caseId, caseNumber, and status
     */
    @AuraEnabled
    public static SaveResult saveCaseAsDraft(Case caseRecord) {
        try {
            caseRecord.Status = 'Draft';
            upsert caseRecord;

            Case saved = [
                SELECT CaseNumber, Status
                FROM   Case
                WHERE  Id = :caseRecord.Id
                LIMIT  1
            ];

            SaveResult result = new SaveResult();
            result.caseId     = caseRecord.Id;
            result.caseNumber = saved.CaseNumber;
            result.status     = saved.Status;
            return result;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
