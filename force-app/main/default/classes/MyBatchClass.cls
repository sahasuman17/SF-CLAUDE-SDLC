public class MyBatchClass implements Database.Batchable<sObject>,Database.AllowsCallouts {
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id FROM Account'); // Example query
    }
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        for (sObject s : scope) {
            Account acc = (Account)s;
            acc.Description = 'Processed by batch';
        }
        update scope;
    }
    public void finish(Database.BatchableContext BC) {
        System.debug('Batch job completed.');
    }
}