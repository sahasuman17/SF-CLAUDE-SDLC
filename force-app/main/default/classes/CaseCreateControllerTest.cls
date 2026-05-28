/**
 * CaseCreateControllerTest
 *
 * Test class for CaseCreateController (MP-8).
 * Covers all three @AuraEnabled methods:
 *   - findAssetBySerial  (positive, no-match, blank input)
 *   - getPartDescription (positive, fake Id)
 *   - saveCaseAsDraft    (insert path, update path, error path)
 *
 * Target coverage: >= 80%
 * API Version: 65.0
 */
@isTest
private class CaseCreateControllerTest {

    // ─── Constants ────────────────────────────────────────────────────────────

    private static final String TEST_SERIAL        = 'TEST-SERIAL-001';
    private static final String TEST_BRAND_NAME    = 'Fendt';
    private static final String TEST_MODEL_NAME    = 'FV2984720';
    private static final String TEST_PRODUCT_TYPE  = 'Tractors';
    private static final String TEST_PRODUCT_SERIES = 'S-Series';
    private static final String TEST_ENGINE_SERIAL = 'ENG-001-TEST';
    private static final String TEST_UOM           = 'Hours';
    private static final Decimal TEST_USAGE        = 1250;
    private static final String TEST_PART_DESC     = 'Hydraulic Filter Assembly';

    // ─── Test Setup ───────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {

        // 1. Brand
        Brand__c brand = new Brand__c(Name = TEST_BRAND_NAME);
        insert brand;

        // 2. Model (linked to Brand)
        Model__c model = new Model__c(
            Name          = TEST_MODEL_NAME,
            Brand_Name__c = brand.Id
        );
        insert model;

        // 3. Product2
        Product2 product = new Product2(
            Name      = 'Test Product',
            Type__c   = TEST_PRODUCT_TYPE,
            Series__c = TEST_PRODUCT_SERIES,
            IsActive  = true
        );
        insert product;

        // 4. Account — required by Asset
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        // 5. Asset
        Asset asset = new Asset(
            Name                    = 'Test Asset',
            SerialNumber            = TEST_SERIAL,
            AccountId               = acct.Id,
            Model_Name__c           = model.Id,
            Product2Id              = product.Id,
            Unit_of_Measure__c      = TEST_UOM,
            Usage__c                = TEST_USAGE,
            Engine_Serial_Number__c = TEST_ENGINE_SERIAL
        );
        insert asset;

        // 6. Part
        Part__c part = new Part__c(
            Name                = 'TEST-PART-001',
            Part_Description__c = TEST_PART_DESC
        );
        insert part;
    }

    @isTest
    static void findAssetBySerial_positiveMatch_returnsPopulatedWrapper() {
        Test.startTest();
        CaseCreateController.AssetWrapper result =
            CaseCreateController.findAssetBySerial(TEST_SERIAL);
        Test.stopTest();

        Assert.isNotNull(result,          'Wrapper should not be null for a matching serial');
        Assert.isNotNull(result.assetId,  'assetId should be populated');
        Assert.areEqual(TEST_BRAND_NAME, result.brand, 'brand should match Brand__c.Name');
        Assert.areEqual(TEST_MODEL_NAME, result.modelNumber, 'modelNumber should match Model__c.Name');
        Assert.areEqual(TEST_PRODUCT_TYPE,   result.machineType, 'machineType should equal TEXT(Product2.Type__c)');
        Assert.areEqual(TEST_PRODUCT_SERIES, result.series, 'series should equal Product2.Series__c');
        Assert.areEqual(TEST_UOM,          result.unitOfMeasure, 'unitOfMeasure should match Asset.Unit_of_Measure__c');
        Assert.areEqual(TEST_ENGINE_SERIAL, result.engineSerial, 'engineSerial should match Asset.Engine_Serial_Number__c');
        Assert.isTrue(result.usageAvailable, 'usageAvailable should be true when Usage__c is set');
        Assert.areEqual(String.valueOf(TEST_USAGE.intValue()), result.machineUsage, 'machineUsage should be Usage__c as integer string');
    }

    @isTest
    static void findAssetBySerial_noMatch_returnsNull() {
        Test.startTest();
        CaseCreateController.AssetWrapper result =
            CaseCreateController.findAssetBySerial('NONEXISTENT-SERIAL-XYZ');
        Test.stopTest();
        Assert.isNull(result, 'Should return null when no Asset matches the serial');
    }

    @isTest
    static void findAssetBySerial_blankInput_returnsNullGracefully() {
        Test.startTest();
        CaseCreateController.AssetWrapper blankResult =
            CaseCreateController.findAssetBySerial('');
        Test.stopTest();
        Assert.isNull(blankResult, 'Should return null for blank serial without throwing');
    }

    @isTest
    static void findAssetBySerial_whitespaceInput_returnsNullGracefully() {
        Test.startTest();
        CaseCreateController.AssetWrapper wsResult =
            CaseCreateController.findAssetBySerial('   ');
        Test.stopTest();
        Assert.isNull(wsResult, 'Should return null for whitespace serial without throwing');
    }

    @isTest
    static void getPartDescription_matchingId_returnsDescription() {
        Part__c part = [SELECT Id FROM Part__c WHERE Name = 'TEST-PART-001' LIMIT 1];
        Test.startTest();
        String description = CaseCreateController.getPartDescription(part.Id);
        Test.stopTest();
        Assert.areEqual(TEST_PART_DESC, description, 'Should return Part_Description__c for matching Part Id');
    }

    @isTest
    static void getPartDescription_fakeId_returnsNull() {
        String keyPrefix  = Part__c.SObjectType.getDescribe().getKeyPrefix();
        Id     fakePartId = (Id)(keyPrefix + '000000000001AAA');
        Test.startTest();
        String description = CaseCreateController.getPartDescription(fakePartId);
        Test.stopTest();
        Assert.isNull(description, 'Should return null when no Part__c record exists for the given Id');
    }

    @isTest
    static void getPartDescription_nullId_returnsNull() {
        Test.startTest();
        String description = CaseCreateController.getPartDescription(null);
        Test.stopTest();
        Assert.isNull(description, 'Should return null without exception when partId is null');
    }

    @isTest
    static void saveCaseAsDraft_insertPath_createsCaseAsDraft() {
        Case caseRecord = new Case(
            Brand__c        = 'Fendt',
            Machine_Type__c = 'Tractors',
            Series__c       = 'S-Series',
            Model_Number__c = 'FV2984720',
            Unit_of_Measure__c = 'Hours',
            Machine_Usage__c   = '1250',
            Used_With__c       = 'Trailer'
        );
        Test.startTest();
        CaseCreateController.SaveResult result =
            CaseCreateController.saveCaseAsDraft(caseRecord);
        Test.stopTest();
        Assert.isNotNull(result,            'SaveResult should not be null');
        Assert.isNotNull(result.caseId,     'caseId should be set after insert');
        Assert.areEqual('Draft', result.status, 'status should be Draft after save');
        Assert.isTrue(String.isNotBlank(result.caseNumber), 'caseNumber should not be blank after insert');
        Integer count = [SELECT COUNT() FROM Case WHERE Id = :result.caseId];
        Assert.areEqual(1, count, 'Exactly one Case should exist for the returned caseId');
    }

    @isTest
    static void saveCaseAsDraft_updatePath_updatesSameRecord() {
        Case caseRecord = new Case(
            Brand__c        = 'Fendt',
            Machine_Type__c = 'Tractors',
            Series__c       = 'S-Series',
            Model_Number__c = 'FV2984720'
        );
        Test.startTest();
        CaseCreateController.SaveResult insertResult =
            CaseCreateController.saveCaseAsDraft(caseRecord);
        Case updateRecord = new Case(
            Id              = insertResult.caseId,
            Brand__c        = 'Fendt',
            Machine_Type__c = 'Tractors',
            Series__c       = 'S-Series',
            Model_Number__c = 'FV2984720-UPDATED',
            Used_With__c    = 'Combine'
        );
        CaseCreateController.SaveResult updateResult =
            CaseCreateController.saveCaseAsDraft(updateRecord);
        Test.stopTest();
        Assert.areEqual(insertResult.caseId, updateResult.caseId, 'caseId should be identical after update');
        Integer caseCount = [SELECT COUNT() FROM Case WHERE Id = :insertResult.caseId];
        Assert.areEqual(1, caseCount, 'Upsert must not create a duplicate Case record');
        Case persisted = [SELECT Model_Number__c, Status FROM Case WHERE Id = :insertResult.caseId];
        Assert.areEqual('FV2984720-UPDATED', persisted.Model_Number__c, 'Model_Number__c should reflect updated value');
        Assert.areEqual('Draft', persisted.Status, 'Status must remain Draft after update');
    }

    @isTest
    static void saveCaseAsDraft_invalidRecord_throwsAuraHandledException() {
        String keyPrefix  = Case.SObjectType.getDescribe().getKeyPrefix();
        Id     fakeId     = (Id)(keyPrefix + '000000000001AAA');
        Case badCase = new Case(Id = fakeId);
        Test.startTest();
        try {
            CaseCreateController.saveCaseAsDraft(badCase);
            Assert.fail('Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'AuraHandledException should be thrown for an invalid Case');
        }
        Test.stopTest();
    }
}
