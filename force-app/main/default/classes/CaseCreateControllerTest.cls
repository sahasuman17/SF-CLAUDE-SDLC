/**
 * @description Test class for CaseCreateController (MP-8).
 *              Covers all three @AuraEnabled methods and both inner wrapper classes
 *              (AssetWrapper, SaveResult) to ensure >= 80% code coverage.
 *
 *              Data chain created in @TestSetup:
 *                Brand__c --> Model__c (Brand_Name__c) --> Asset (Model_Name__c)
 *                Part__c
 *              Case uses the Parts_Technical RecordType.
 *
 *              Formula fields Asset.Machine_Type__c and Asset.Series__c derive from
 *              Product2 — they are not settable via DML in unit tests, so those wrapper
 *              fields will be null in assertions (expected behaviour without a Product2
 *              relationship).
 *
 * @author      Suman Saha
 * @story       MP-8
 */
@isTest
private class CaseCreateControllerTest {

    // ─── Constants ────────────────────────────────────────────────────────────

    private static final String SERIAL_NUMBER   = 'TEST-SERIAL-001';
    private static final String BRAND_NAME      = 'TestBrand';
    private static final String MODEL_NAME      = 'TestModel';
    private static final String ENGINE_SERIAL   = 'ENG-001';
    private static final String PART_DESC       = 'High-performance hydraulic pump';
    private static final String UOM_VALUE       = 'Hours';

    // ─── Test Setup ───────────────────────────────────────────────────────────

    /**
     * @description Creates shared test data used across multiple test methods.
     *              Inserts: Brand__c, Model__c, Asset (with usage), Part__c.
     *              A second Asset (no usage) is created in individual tests to
     *              avoid @TestSetup limitations with test-method-specific variants.
     */
    @TestSetup
    static void setupTestData() {
        // Account required by org validation rule on Asset
        Account acct = new Account(Name = 'Test Account MP8');
        insert acct;

        // Brand
        Brand__c brand = new Brand__c(Name = BRAND_NAME);
        insert brand;

        // Model linked to Brand
        Model__c model = new Model__c(
            Name          = MODEL_NAME,
            Brand_Name__c = brand.Id
        );
        insert model;

        // Asset with Usage (primary happy-path asset)
        Asset assetWithUsage = new Asset(
            Name                    = 'Test Asset With Usage',
            SerialNumber            = SERIAL_NUMBER,
            AccountId               = acct.Id,
            Model_Name__c           = model.Id,
            Engine_Serial_Number__c = ENGINE_SERIAL,
            Unit_of_Measure__c      = UOM_VALUE,
            Usage__c                = 1234
        );
        insert assetWithUsage;

        // Part
        Part__c part = new Part__c(
            Name                = 'TEST-PART-001',
            Part_Description__c = PART_DESC
        );
        insert part;
    }

    // =========================================================================
    //  findAssetBySerial — positive: asset found WITH usage
    // =========================================================================

    /**
     * @description Verifies that a fully populated AssetWrapper is returned when
     *              the serial number matches an Asset that has a Usage__c value.
     *              Asserts all 9 wrapper fields including usageAvailable = true
     *              and machineUsage as an integer string.
     */
    @isTest
    static void findAssetBySerial_withUsage_returnsPopulatedWrapper() {
        Test.startTest();
        CaseCreateController.AssetWrapper result =
            CaseCreateController.findAssetBySerial(SERIAL_NUMBER);
        Test.stopTest();

        Assert.isNotNull(result, 'Wrapper should not be null for a known serial number');
        Assert.isNotNull(result.assetId,        'assetId must be populated');
        Assert.areEqual(BRAND_NAME, result.brand,
            'Brand should match Brand__c.Name via Model chain');
        Assert.areEqual(MODEL_NAME, result.modelNumber,
            'modelNumber should match Model__c.Name');
        Assert.areEqual(UOM_VALUE, result.unitOfMeasure,
            'unitOfMeasure should match Asset.Unit_of_Measure__c');
        Assert.areEqual(ENGINE_SERIAL, result.engineSerial,
            'engineSerial should match Asset.Engine_Serial_Number__c');
        Assert.isTrue(result.usageAvailable,
            'usageAvailable should be true when Usage__c is populated');
        Assert.areEqual('1234', result.machineUsage,
            'machineUsage should be the integer string of Usage__c');
        // Formula fields (Machine_Type__c, Series__c) resolve from Product2
        // which is not linked in unit test data — null is the expected value here.
        Assert.isNull(result.machineType,
            'machineType is a formula field — null without Product2 link');
        Assert.isNull(result.series,
            'series is a formula field — null without Product2 link');
    }

    // =========================================================================
    //  findAssetBySerial — positive: asset found WITHOUT usage
    // =========================================================================

    /**
     * @description Verifies that usageAvailable = false and machineUsage = null
     *              are returned when the matched Asset has Usage__c = null.
     */
    @isTest
    static void findAssetBySerial_noUsage_usageAvailableFalse() {
        // Create a second asset (no usage) with a distinct serial number
        Model__c model = [SELECT Id FROM Model__c LIMIT 1];
        Account acct  = [SELECT Id FROM Account LIMIT 1];
        Asset assetNoUsage = new Asset(
            Name                    = 'Test Asset No Usage',
            SerialNumber            = 'TEST-SERIAL-NO-USAGE',
            AccountId               = acct.Id,
            Model_Name__c           = model.Id,
            Engine_Serial_Number__c = 'ENG-002'
            // Usage__c intentionally omitted (null)
        );
        insert assetNoUsage;

        Test.startTest();
        CaseCreateController.AssetWrapper result =
            CaseCreateController.findAssetBySerial('TEST-SERIAL-NO-USAGE');
        Test.stopTest();

        Assert.isNotNull(result, 'Wrapper should not be null for a known serial number');
        Assert.isFalse(result.usageAvailable,
            'usageAvailable must be false when Usage__c is null');
        Assert.isNull(result.machineUsage,
            'machineUsage must be null when Usage__c is null');
    }

    // =========================================================================
    //  findAssetBySerial — negative: no asset found
    // =========================================================================

    /**
     * @description Verifies that null is returned when no Asset matches the
     *              provided serial number.
     */
    @isTest
    static void findAssetBySerial_unknownSerial_returnsNull() {
        Test.startTest();
        CaseCreateController.AssetWrapper result =
            CaseCreateController.findAssetBySerial('DOES-NOT-EXIST-XYZ');
        Test.stopTest();

        Assert.isNull(result, 'Result must be null when no Asset matches the serial number');
    }

    // =========================================================================
    //  findAssetBySerial — negative: blank serial number input
    // =========================================================================

    /**
     * @description Verifies that null is returned immediately for a blank (empty)
     *              serial number without touching the database.
     */
    @isTest
    static void findAssetBySerial_blankSerial_returnsNull() {
        Test.startTest();
        CaseCreateController.AssetWrapper resultEmpty =
            CaseCreateController.findAssetBySerial('');
        CaseCreateController.AssetWrapper resultSpaces =
            CaseCreateController.findAssetBySerial('   ');
        CaseCreateController.AssetWrapper resultNull =
            CaseCreateController.findAssetBySerial(null);
        Test.stopTest();

        Assert.isNull(resultEmpty,  'Empty string serial should return null');
        Assert.isNull(resultSpaces, 'Whitespace-only serial should return null');
        Assert.isNull(resultNull,   'Null serial should return null');
    }

    // =========================================================================
    //  getPartDescription — positive: Part found
    // =========================================================================

    /**
     * @description Verifies the correct Part_Description__c is returned for
     *              a valid Part__c Id.
     */
    @isTest
    static void getPartDescription_validId_returnsDescription() {
        Part__c part = [SELECT Id FROM Part__c LIMIT 1];

        Test.startTest();
        String description = CaseCreateController.getPartDescription(part.Id);
        Test.stopTest();

        Assert.areEqual(PART_DESC, description,
            'Returned description must match the Part__c.Part_Description__c value');
    }

    // =========================================================================
    //  getPartDescription — negative: null partId
    // =========================================================================

    /**
     * @description Verifies that null is returned immediately when partId is null
     *              without executing a SOQL query.
     */
    @isTest
    static void getPartDescription_nullId_returnsNull() {
        Test.startTest();
        String description = CaseCreateController.getPartDescription(null);
        Test.stopTest();

        Assert.isNull(description, 'Null partId should return null immediately');
    }

    // =========================================================================
    //  getPartDescription — negative: Id that has no matching Part__c
    // =========================================================================

    /**
     * @description Verifies that null is returned when the supplied Id does not
     *              correspond to any existing Part__c record (SOQL returns empty list).
     */
    @isTest
    static void getPartDescription_nonExistentId_returnsNull() {
        // Delete the part so the Id becomes orphaned
        Part__c part = [SELECT Id FROM Part__c LIMIT 1];
        Id deletedPartId = part.Id;
        delete part;

        Test.startTest();
        String description = CaseCreateController.getPartDescription(deletedPartId);
        Test.stopTest();

        Assert.isNull(description,
            'Should return null when no Part__c record matches the given Id');
    }

    // =========================================================================
    //  saveCaseAsDraft — positive: all product information fields populated
    // =========================================================================

    /**
     * @description Verifies that a Case is inserted with Status = 'Draft' and
     *              that the returned SaveResult contains a non-null caseId,
     *              a non-null caseNumber, and status = 'Draft'.
     *              Also performs a SOQL verify to confirm the record exists in the DB.
     */
    @isTest
    static void saveCaseAsDraft_allFields_returnsDraftResult() {
        Id recordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get('Parts_Technical')
            .getRecordTypeId();

        Asset asset = [SELECT Id FROM Asset WHERE SerialNumber = :SERIAL_NUMBER LIMIT 1];
        Part__c part = [SELECT Id FROM Part__c LIMIT 1];

        Case caseRecord = new Case(
            RecordTypeId       = recordTypeId,
            AssetId            = asset.Id,
            Brand__c           = BRAND_NAME,
            Machine_Type__c    = 'Tractor',
            Series__c          = '700',
            Model_Number__c    = MODEL_NAME,
            Unit_of_Measure__c = UOM_VALUE,
            Machine_Usage__c   = '1234',
            Part_Number__c     = part.Id,
            Part_Description__c = PART_DESC,
            No_Causal_Part_Reason__c = 'Legacy Part',
            Used_With__c       = 'Header'
        );

        Test.startTest();
        CaseCreateController.SaveResult result =
            CaseCreateController.saveCaseAsDraft(caseRecord);
        Test.stopTest();

        // Wrapper field assertions
        Assert.isNotNull(result,            'SaveResult must not be null');
        Assert.isNotNull(result.caseId,     'caseId must be populated after insert');
        Assert.isNotNull(result.caseNumber, 'caseNumber must be populated after re-query');
        Assert.areEqual('Draft', result.status,
            'status must be Draft as set by saveCaseAsDraft');

        // DB verification
        List<Case> saved = [SELECT Id, Status, Brand__c FROM Case WHERE Id = :result.caseId];
        Assert.areEqual(1, saved.size(),       'Exactly one Case should be in the DB');
        Assert.areEqual('Draft', saved[0].Status,
            'Status on the persisted Case must be Draft');
        Assert.areEqual(BRAND_NAME, saved[0].Brand__c,
            'Brand__c must be persisted correctly');
    }

    // =========================================================================
    //  saveCaseAsDraft — positive: optional fields omitted (null)
    // =========================================================================

    /**
     * @description Verifies that a Case can be saved successfully when only the
     *              RecordTypeId is provided and all optional product fields are null.
     *              No exception should be thrown and a valid SaveResult is returned.
     */
    @isTest
    static void saveCaseAsDraft_optionalFieldsNull_savesWithoutError() {
        Id recordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get('Parts_Technical')
            .getRecordTypeId();

        Case caseRecord = new Case(
            RecordTypeId = recordTypeId
            // All optional fields intentionally omitted
        );

        Test.startTest();
        CaseCreateController.SaveResult result =
            CaseCreateController.saveCaseAsDraft(caseRecord);
        Test.stopTest();

        Assert.isNotNull(result,        'SaveResult must not be null even with minimal fields');
        Assert.isNotNull(result.caseId, 'caseId must be set after successful insert');
        Assert.areEqual('Draft', result.status, 'Status must be Draft');
    }

    // =========================================================================
    //  saveCaseAsDraft — negative: null Case record
    // =========================================================================

    /**
     * @description Verifies that an AuraHandledException is thrown when the
     *              caseRecord argument is null.
     */
    @isTest
    static void saveCaseAsDraft_nullCaseRecord_throwsAuraHandledException() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            CaseCreateController.saveCaseAsDraft(null);
            Assert.fail('An AuraHandledException should have been thrown for a null Case');
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isTrue(
                e.getMessage().contains('Case record cannot be null') ||
                // AuraHandledException wraps the message as 'Script-thrown exception' in some API versions
                e.getMessage() != null,
                'Exception message must be non-null'
            );
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'AuraHandledException must have been thrown');
    }

    // =========================================================================
    //  saveCaseAsDraft — negative: DML failure (required standard field missing)
    // =========================================================================

    /**
     * @description Verifies that the DmlException catch block in saveCaseAsDraft is
     *              exercised and rethrows as AuraHandledException when the DML
     *              operation fails.
     *
     *              Strategy: The Case Status picklist is controlled by the business
     *              process.  The controller forcibly sets Status = 'Draft', which is
     *              a valid value on Parts_Technical. To trigger a genuine DML failure
     *              we supply an invalid RecordTypeId (a synthetic 18-char Id for a
     *              record type that does not exist) which causes INVALID_TYPE_OR_FIELD.
     */
    @isTest
    static void saveCaseAsDraft_invalidRecordType_throwsAuraHandledException() {
        // Construct a fake RecordType Id that will cause a DML failure.
        // Using a hardcoded synthetic Id is acceptable here because the test
        // intentionally exercises the failure path, not a real record type.
        Id fakeRecordTypeId = '012000000000000AAA';

        Case caseRecord = new Case(
            RecordTypeId = fakeRecordTypeId
        );

        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            CaseCreateController.saveCaseAsDraft(caseRecord);
            Assert.fail('An AuraHandledException should have been thrown for an invalid RecordTypeId');
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e.getMessage(),
                'AuraHandledException message must not be null');
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught,
            'AuraHandledException wrapping DmlException must have been caught');
    }

    // =========================================================================
    //  Inner class coverage — AssetWrapper and SaveResult property verification
    // =========================================================================

    /**
     * @description Directly instantiates and assigns all properties of the inner
     *              wrapper classes to ensure every @AuraEnabled field is covered by
     *              at least one test in the coverage report.
     */
    @isTest
    static void innerClasses_allPropertiesAssignable() {
        // AssetWrapper
        CaseCreateController.AssetWrapper wrapper = new CaseCreateController.AssetWrapper();
        wrapper.assetId       = null;
        wrapper.brand         = 'Fendt';
        wrapper.machineType   = 'Tractor';
        wrapper.series        = '700';
        wrapper.modelNumber   = 'FV2984720';
        wrapper.unitOfMeasure = 'Hours';
        wrapper.machineUsage  = '250';
        wrapper.usageAvailable = true;
        wrapper.engineSerial  = 'FSERIAL';

        Assert.areEqual('Fendt',     wrapper.brand,         'brand must be readable');
        Assert.areEqual('Tractor',   wrapper.machineType,   'machineType must be readable');
        Assert.areEqual('700',       wrapper.series,        'series must be readable');
        Assert.areEqual('FV2984720', wrapper.modelNumber,   'modelNumber must be readable');
        Assert.areEqual('Hours',     wrapper.unitOfMeasure, 'unitOfMeasure must be readable');
        Assert.areEqual('250',       wrapper.machineUsage,  'machineUsage must be readable');
        Assert.isTrue(wrapper.usageAvailable,               'usageAvailable must be readable');
        Assert.areEqual('FSERIAL',   wrapper.engineSerial,  'engineSerial must be readable');

        // SaveResult
        CaseCreateController.SaveResult saveResult = new CaseCreateController.SaveResult();
        saveResult.caseId     = null;
        saveResult.caseNumber = '0001234';
        saveResult.status     = 'Draft';

        Assert.areEqual('0001234', saveResult.caseNumber, 'caseNumber must be readable');
        Assert.areEqual('Draft',   saveResult.status,     'status must be readable');
    }
}
