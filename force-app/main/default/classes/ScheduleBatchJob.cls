public class ScheduleBatchJob {
    public static void scheduleMyBatch() {
        // Set batch job instance
        MyBatchClass batchInstance = new MyBatchClass();

        // Set the batch job name
        String jobName = 'Scheduled Batch Job';

        // Define delay in seconds (e.g., 5 minutes = 300 seconds)
        Integer delayInSeconds = 300;

        // Schedule the batch job using System.scheduleBatch
        System.scheduleBatch(batchInstance, jobName, delayInSeconds);
    }
}