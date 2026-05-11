<!-- Parent: sf-apex/SKILL.md -->
# Apex Testing Reference

Comprehensive guide to Apex testing: fundamentals, Spring '26 annotations, Assert class, exception types, test patterns, mocking, stubs, bulk testing, coverage strategies, and more.

---

## Table of Contents

1. [Testing Fundamentals](#testing-fundamentals)
2. [Spring '26 Test Annotations](#spring-26-test-annotations)
3. [Assert Class (Winter '23+)](#assert-class-winter-23)
4. [Common Exception Types](#common-exception-types)
5. [Test Patterns](#test-patterns)
6. [Test Data Factory](#test-data-factory)
7. [Mocking and Stubs](#mocking-and-stubs)
8. [Bulk Testing](#bulk-testing)
9. [Testing Governor Limits](#testing-governor-limits)
10. [Testing Private Methods](#testing-private-methods)
11. [Code Coverage Strategies](#code-coverage-strategies)
12. [Test Checklist](#test-checklist)

---

## Testing Fundamentals

### Coverage Requirements
- **Minimum**: 75% for deployment
- **Recommended**: 90%+ for quality
- **Best Practice**: Maintain buffer above 75%

### Test Class Structure

```apex
@isTest
private class AccountServiceTest {

    @TestSetup
    static void setup() {
        // Runs ONCE before all test methods — shared test data
        TestDataFactory.createAccounts(10);
    }

    @isTest
    static void testPositiveScenario() {
        // Arrange
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Act
        Test.startTest();
        String result = AccountService.processAccount(acc.Id);
        Test.stopTest();

        // Assert
        Assert.areEqual('Success', result, 'Should return success');
    }

    @isTest
    static void testNegativeScenario() {
        Test.startTest();
        try {
            AccountService.processAccount(null);
            Assert.fail('Should have thrown exception');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('null'), 'Should mention null');
        }
        Test.stopTest();
    }

    @isTest
    static void testBulkScenario() {
        // 251+ records spans two trigger batches
        List<Account> accounts = TestDataFactory.createAccounts(251);

        Test.startTest();
        List<String> results = AccountService.processAccounts(accounts);
        Test.stopTest();

        Assert.areEqual(251, results.size(), 'Should process all records');
    }
}
```

---

### @TestSetup

| Feature | @TestSetup | Test Methods |
|---------|------------|--------------|
| **Runs** | Once before all tests | Once per test |
| **Data Isolation** | Shared across tests (read-only view) | Isolated per test |
| **Performance** | Faster (reuses data) | Slower (recreates each time) |
| **When to Use** | Common baseline data | Test-specific scenarios |

```apex
@TestSetup
static void setup() {
    insert new Account(Name = 'Shared Account');
}

@isTest
static void test1() {
    Account acc = [SELECT Id FROM Account WHERE Name = 'Shared Account'];
    acc.Industry = 'Tech';
    update acc;  // Only visible in this test
}

@isTest
static void test2() {
    // Industry = null — data rolled back between tests
    Account acc = [SELECT Id, Industry FROM Account WHERE Name = 'Shared Account'];
    Assert.isNull(acc.Industry);
}
```

---

### Test.startTest() and Test.stopTest()

Resets governor limits and executes async code synchronously.

```apex
@isTest
static void testAsyncOperation() {
    Account acc = new Account(Name = 'Test');
    insert acc;

    Test.startTest();                                   // limits reset here
    System.enqueueJob(new AccountProcessor(acc.Id));
    Test.stopTest();                                    // async executes here

    Account updated = [SELECT Id, Description FROM Account WHERE Id = :acc.Id];
    Assert.isNotNull(updated.Description);
}
```

**Key points:**
- Governor limits reset at `Test.startTest()`
- Async code (@future, Queueable, Batch, Schedulable) executes at `Test.stopTest()`
- Only one `startTest/stopTest` block per test method

---

## Spring '26 Test Annotations

### `@isTest(testFor=ClassName.class)` — Test-to-Source Linking

Explicitly links a test class to the production class it covers. Improves coverage attribution and supports `RunRelevantTests` deployment mode.

```apex
@isTest(testFor=AccountService.class)
private class AccountServiceTest {
    // All test methods here count toward AccountService coverage
}
```

### `@isTest(isCritical=true)` — Always-Run Tests

Marks tests that must always execute, even when using `RunRelevantTests` test level. Use for smoke tests, critical business logic, and integration test entry points.

```apex
@isTest(isCritical=true)
private class PaymentProcessorTest {
    // Runs even in RunRelevantTests mode
}
```

Can combine both:
```apex
@isTest(testFor=PaymentProcessor.class, isCritical=true)
private class PaymentProcessorTest { }
```

---

## Assert Class (Winter '23+)

### Preferred Assert Methods

```apex
// Equality
Assert.areEqual(expected, actual, 'Optional message');
Assert.areNotEqual(unexpected, actual);

// Boolean
Assert.isTrue(condition, 'Should be true');
Assert.isFalse(condition, 'Should be false');

// Null
Assert.isNull(value, 'Should be null');
Assert.isNotNull(value, 'Should not be null');

// Instance type
Assert.isInstanceOfType(obj, Account.class, 'Should be Account');

// Explicit failure
Assert.fail('This should not be reached');
```

### Testing Exceptions

```apex
@isTest
static void testExceptionThrown() {
    Test.startTest();
    try {
        MyService.riskyOperation();
        Assert.fail('Expected MyCustomException');
    } catch (MyCustomException e) {
        Assert.isTrue(e.getMessage().contains('expected text'));
    }
    Test.stopTest();
}
```

---

## Common Exception Types

| Exception Type | When to Use | Example |
|----------------|-------------|---------|
| `DmlException` | Insert/update/delete failures | `FIELD_CUSTOM_VALIDATION`, `REQUIRED_FIELD_MISSING` |
| `QueryException` | SOQL failures | No rows for assignment, too many rows |
| `NullPointerException` | Null reference access | Accessing field on null object |
| `ListException` | List operation failures | Index out of bounds |
| `MathException` | Mathematical errors | Division by zero |
| `TypeException` | Type conversion failures | Invalid casting |
| `LimitException` | Governor limit exceeded | Too many SOQL queries, DML statements |
| `CalloutException` | HTTP callout failures | Timeout, invalid endpoint |
| `JSONException` | JSON parsing failures | Malformed JSON |
| `InvalidParameterValueException` | Invalid method parameters | Bad input values |

### Testing DmlException

```apex
@isTest
static void testRequiredFieldMissing() {
    try {
        insert new Account(); // Missing Name
        Assert.fail('Expected DmlException was not thrown');
    } catch (DmlException e) {
        Assert.isTrue(
            e.getMessage().contains('REQUIRED_FIELD_MISSING'),
            'Expected REQUIRED_FIELD_MISSING but got: ' + e.getMessage()
        );
    }
}

@isTest
static void testCustomValidationRule() {
    Account acc = new Account(Name = 'Test', AnnualRevenue = -100);
    try {
        insert acc;
        Assert.fail('Expected DmlException');
    } catch (DmlException e) {
        Assert.isTrue(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
    }
}
```

### Testing QueryException

```apex
@isTest
static void testNoRowsForAssignment() {
    try {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Nonexistent'];
        Assert.fail('Expected QueryException');
    } catch (QueryException e) {
        Assert.isTrue(e.getMessage().contains('List has no rows for assignment'));
    }
}
```

### Testing NullPointerException

```apex
@isTest
static void testSafeNavigationOperator() {
    Account acc = null;
    String name = acc?.Name;  // No exception — returns null
    Assert.isNull(name, 'Safe navigation should return null');
}
```

### Testing CalloutException

```apex
@isTest
static void testCalloutTimeout() {
    Test.setMock(HttpCalloutMock.class, new TimeoutMock());

    Test.startTest();
    try {
        CalloutService.sendData('test');
        Assert.fail('Expected CalloutException');
    } catch (CalloutException e) {
        Assert.isTrue(e.getMessage().contains('Read timed out'));
    }
    Test.stopTest();
}

private class TimeoutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        throw new CalloutException('Read timed out');
    }
}
```

---

## Test Patterns

### Pattern 1: Positive, Negative, Bulk (PNB)

Every feature needs 3 tests:

```apex
// 1. POSITIVE: Happy path
@isTest
static void testCreateAccountSuccess() {
    Account acc = new Account(Name = 'Test', Industry = 'Tech');
    Test.startTest();
    insert acc;
    Test.stopTest();

    Account inserted = [SELECT Id, Industry FROM Account WHERE Id = :acc.Id];
    Assert.areEqual('Tech', inserted.Industry);
}

// 2. NEGATIVE: Error handling
@isTest
static void testCreateAccountMissingName() {
    try {
        insert new Account();
        Assert.fail('Expected exception');
    } catch (DmlException e) {
        Assert.isTrue(e.getMessage().contains('REQUIRED_FIELD_MISSING'));
    }
}

// 3. BULK: 251+ records
@isTest
static void testCreateAccountsBulk() {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 251; i++) {
        accounts.add(new Account(Name = 'Bulk ' + i));
    }
    Test.startTest();
    insert accounts;
    Test.stopTest();

    Assert.areEqual(251, [SELECT COUNT() FROM Account]);
}
```

---

### Pattern 2: System.runAs() for Permission Testing

```apex
@isTest
static void testUserCannotAccessRestrictedField() {
    User restrictedUser = TestDataFactory.createStandardUser();
    Account acc = new Account(Name = 'Test', Restricted_Field__c = 'Secret');
    insert acc;

    System.runAs(restrictedUser) {
        try {
            List<Account> accounts = [
                SELECT Id, Restricted_Field__c FROM Account
                WHERE Id = :acc.Id
                WITH USER_MODE
            ];
            Assert.fail('Expected QueryException due to FLS');
        } catch (QueryException e) {
            Assert.isTrue(e.getMessage().contains('Insufficient privileges'));
        }
    }
}

@isTest
static void testAsAdmin() {
    User adminUser = TestDataFactory.createUser('System Administrator');
    System.runAs(adminUser) {
        // Test admin-specific functionality
    }
}
```

---

### Pattern 3: Database Methods for Partial Success

```apex
@isTest
static void testPartialInsertSuccess() {
    List<Account> accounts = new List<Account>{
        new Account(Name = 'Valid Account'),
        new Account(),              // Invalid — missing Name
        new Account(Name = 'Another Valid')
    };

    Test.startTest();
    Database.SaveResult[] results = Database.insert(accounts, false); // allOrNone = false
    Test.stopTest();

    Integer successCount = 0;
    Integer failureCount = 0;
    for (Database.SaveResult result : results) {
        if (result.isSuccess()) {
            successCount++;
        } else {
            failureCount++;
            for (Database.Error err : result.getErrors()) {
                Assert.areEqual(StatusCode.REQUIRED_FIELD_MISSING, err.getStatusCode());
            }
        }
    }

    Assert.areEqual(2, successCount, 'Two accounts should succeed');
    Assert.areEqual(1, failureCount, 'One account should fail');
}
```

---

### Pattern 4: Testing Async Code

```apex
// @future
@isTest
static void testFutureMethod() {
    Account acc = new Account(Name = 'Test');
    insert acc;

    Test.startTest();
    AccountService.updateAsync(acc.Id);
    Test.stopTest();

    Account updated = [SELECT Description FROM Account WHERE Id = :acc.Id];
    Assert.areEqual('Updated by future', updated.Description);
}

// Queueable
@isTest
static void testQueueable() {
    Account acc = new Account(Name = 'Test');
    insert acc;

    Test.startTest();
    System.enqueueJob(new AccountProcessor(acc.Id));
    Test.stopTest();

    Account updated = [SELECT Status__c FROM Account WHERE Id = :acc.Id];
    Assert.areEqual('Processed', updated.Status__c);
}

// Batch
@isTest
static void testBatch() {
    TestDataFactory.createAccounts(200);

    Test.startTest();
    Database.executeBatch(new AccountBatchProcessor(), 100);
    Test.stopTest();

    Integer processed = [SELECT COUNT() FROM Account WHERE Description = 'Processed'];
    Assert.areEqual(200, processed);
}

// Schedulable
@isTest
static void testSchedulable() {
    String cronExp = '0 0 0 * * ?';

    Test.startTest();
    String jobId = System.schedule('Test Job', cronExp, new AccountScheduler());
    Test.stopTest();

    CronTrigger ct = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
    Assert.areEqual(cronExp, ct.CronExpression);
}
```

---

## Test Data Factory

### Basic Factory Pattern

```apex
@isTest
public class TestDataFactory {

    public static List<Account> createAccounts(Integer count) {
        return createAccounts(count, true);
    }

    public static List<Account> createAccounts(Integer count, Boolean doInsert) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                Industry = 'Technology',
                BillingCity = 'San Francisco'
            ));
        }
        if (doInsert) {
            insert accounts;
        }
        return accounts;
    }

    public static List<Contact> createContacts(Integer count, Id accountId) {
        return createContacts(count, accountId, true);
    }

    public static List<Contact> createContacts(Integer count, Id accountId, Boolean doInsert) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'test' + i + '@example.com',
                AccountId = accountId
            ));
        }
        if (doInsert) {
            insert contacts;
        }
        return contacts;
    }

    public static User createStandardUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test', LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    public static User createUser(String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniqueKey = String.valueOf(DateTime.now().getTime());
        User u = new User(
            Alias = 'test' + uniqueKey.right(4),
            Email = 'test' + uniqueKey + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'test' + uniqueKey + '@example.com.test'
        );
        insert u;
        return u;
    }
}
```

### Builder Pattern (Complex Objects)

```apex
@isTest
public class AccountBuilder {
    private Account record;

    public AccountBuilder() {
        this.record = new Account(Name = 'Default Account', Industry = 'Technology');
    }

    public AccountBuilder withName(String name) {
        this.record.Name = name;
        return this;
    }

    public AccountBuilder withIndustry(String industry) {
        this.record.Industry = industry;
        return this;
    }

    public AccountBuilder withRevenue(Decimal revenue) {
        this.record.AnnualRevenue = revenue;
        return this;
    }

    public AccountBuilder withBillingAddress(String city, String state) {
        this.record.BillingCity = city;
        this.record.BillingState = state;
        return this;
    }

    public Account build() { return this.record; }

    public Account buildAndInsert() {
        insert this.record;
        return this.record;
    }
}

// Usage
Account acc = new AccountBuilder()
    .withName('Acme Corp')
    .withIndustry('Technology')
    .withRevenue(5000000)
    .withBillingAddress('San Francisco', 'CA')
    .buildAndInsert();
```

---

## Mocking and Stubs

### HttpCalloutMock

```apex
@isTest
public class ExternalServiceMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        Assert.areEqual('POST', req.getMethod());
        Assert.areEqual('https://api.example.com/accounts', req.getEndpoint());

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"status": "success", "id": "12345"}');
        res.setStatusCode(200);
        return res;
    }
}

// Usage
@isTest
static void testCallout() {
    Test.setMock(HttpCalloutMock.class, new ExternalServiceMock());
    Test.startTest();
    String result = CalloutService.sendData('test data');
    Test.stopTest();

    Assert.areEqual('12345', result);
}
```

### Multi-Response Mock (endpoint-keyed)

```apex
public class MultiMockHttpResponse implements HttpCalloutMock {
    private Map<String, HttpResponse> responses = new Map<String, HttpResponse>();

    public void addResponse(String endpoint, Integer statusCode, String body) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(body);
        responses.put(endpoint, res);
    }

    public HTTPResponse respond(HTTPRequest req) {
        String endpoint = req.getEndpoint();
        if (responses.containsKey(endpoint)) {
            return responses.get(endpoint);
        }
        throw new CalloutException('No mock for: ' + endpoint);
    }
}
```

### Stub API (Test Doubles)

```apex
@isTest
public class AccountSelectorStub implements IAccountSelector {
    private List<Account> stubbedAccounts;

    public AccountSelectorStub(List<Account> accounts) {
        this.stubbedAccounts = accounts;
    }

    public List<Account> selectById(Set<Id> accountIds) {
        return stubbedAccounts;
    }
}

// Usage — no DML needed
@isTest
static void testWithStub() {
    List<Account> stubbedAccounts = new List<Account>{
        new Account(Id = TestUtility.getFakeId(Account.SObjectType), Name = 'Stub Account')
    };

    AccountService service = new AccountService(new AccountSelectorStub(stubbedAccounts));

    Test.startTest();
    List<Account> results = service.getAccounts();
    Test.stopTest();

    Assert.areEqual(1, results.size());
    Assert.areEqual('Stub Account', results[0].Name);
}
```

### Dependency Injection via Factory

```apex
// Production code
public virtual class Factory {
    private static Factory instance;

    public static Factory getInstance() {
        if (instance == null) {
            instance = new Factory();
        }
        return instance;
    }

    @TestVisible
    private static void setInstance(Factory mockFactory) {
        instance = mockFactory;
    }

    public virtual AccountService getAccountService() {
        return new AccountService();
    }
}

// Test
@isTest
static void testWithMock() {
    Factory.setInstance(new MockFactory());
    Test.startTest();
    // Code uses MockFactory.getAccountService()
    Test.stopTest();
}

private class MockFactory extends Factory {
    public override AccountService getAccountService() {
        return new MockAccountService();
    }
}
```

---

## Bulk Testing

### The 251 Record Test

```apex
@isTest
static void testBulkTriggerExecution() {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 251; i++) {
        accounts.add(new Account(Name = 'Bulk Test ' + i, Industry = 'Technology'));
    }

    Test.startTest();
    insert accounts;
    Test.stopTest();

    List<Account> inserted = [SELECT Id, Description FROM Account WHERE Name LIKE 'Bulk Test%'];
    Assert.areEqual(251, inserted.size());
    for (Account acc : inserted) {
        Assert.isNotNull(acc.Description, 'Description should be set by trigger');
    }
}
```

---

## Testing Governor Limits

```apex
@isTest
static void testDoesNotHitSoqlLimit() {
    TestDataFactory.createAccounts(251);

    Integer queriesBefore = Limits.getQueries();
    Test.startTest();
    AccountService.processAllAccounts();
    Test.stopTest();

    Integer queriesUsed = Limits.getQueries() - queriesBefore;
    Assert.isTrue(queriesUsed <= 5, 'Should use no more than 5 SOQL queries, used: ' + queriesUsed);
}
```

---

## Testing Private Methods

### @TestVisible Annotation

```apex
public class MyService {
    @TestVisible
    private static String privateMethod(String input) {
        return input.toUpperCase();
    }
}

@isTest
static void testPrivateMethod() {
    String result = MyService.privateMethod('test');
    Assert.areEqual('TEST', result);
}
```

---

## Code Coverage Strategies

### Achieving 90%+ Coverage

**Test all branches (if/else):**
```apex
@isTest
static void testEnterpriseStatus() {
    Account acc = new Account(Name = 'Test', AnnualRevenue = 2000000);
    Assert.areEqual('Enterprise', AccountService.getStatus(acc));
}

@isTest
static void testSmbStatus() {
    Account acc = new Account(Name = 'Test', AnnualRevenue = 500000);
    Assert.areEqual('SMB', AccountService.getStatus(acc));
}
```

**Test all catch blocks:**
```apex
@isTest
static void testCatchBlock() {
    List<Account> invalid = new List<Account>{ new Account() }; // Missing Name
    try {
        insert invalid;
    } catch (DmlException e) {
        // Catch block covered
    }
}
```

### Identifying Uncovered Code

**CLI:**
```bash
sf apex run test --code-coverage --result-format human --test-level RunLocalTests
```

**VS Code:** `Ctrl+Shift+P` → "SFDX: Run Apex Tests" → view coverage in Problems panel

**Developer Console:** Open class → Tests → New Run → select test class → view red highlights

---

## Test Checklist

| Scenario | Required |
|----------|----------|
| Positive test (happy path) | ✓ |
| Negative test (error handling) | ✓ |
| Bulk test (251+ records) | ✓ |
| Single record test | ✓ |
| Null/empty input | ✓ |
| Boundary conditions | ✓ |
| Different user profiles | ✓ |
| Assert statements in every test | ✓ |
| Test.startTest()/stopTest() for async | ✓ |
| All if/else branches covered | ✓ |
| All catch blocks covered | ✓ |
