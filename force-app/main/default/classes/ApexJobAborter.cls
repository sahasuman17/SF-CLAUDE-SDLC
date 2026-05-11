/**
 * @description     Utility class to abort incomplete Apex jobs and scheduled jobs via CronTrigger.
 *                  Handles Batchable, Queueable, and Scheduled Apex Jobs (via AsyncApexJob & CronTrigger).
 * @author          Debanjan Mukherjee
 * @createdDate     07 July 2025
 */
public class ApexJobAborter {

    /**
     * Aborts all incomplete (non-scheduled) Apex jobs.
     */
    public static void abortIncompleteApexJobs() {
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, ApexClass.Name, JobType
            FROM AsyncApexJob
            WHERE Status IN ('Queued', 'Processing', 'Preparing', 'Holding')
            AND JobType != 'ScheduledApex'
        ];

        for (AsyncApexJob job : jobs) {
            try {
                System.abortJob(job.Id);
            } catch (Exception ex) {
                // Skip failure and proceed to next job
            }
        }
    }

    /**
     * Aborts all scheduled jobs that are pending execution using CronTrigger.
     */
    public static void abortScheduledApexJobs() {
        List<CronTrigger> cronJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE State = 'WAITING'
        ];

        for (CronTrigger ct : cronJobs) {
            try {
                System.abortJob(ct.Id);
            } catch (Exception ex) {
                // Skip failure and proceed to next CronTrigger
            }
        }
    }

    /**
     * Public method to abort all incomplete and scheduled jobs.
     */
    public static void abortAllJobs() {
        abortIncompleteApexJobs();
        abortScheduledApexJobs();
    }
    
    public static void abortJobsById(Set<Id> jobIds) {
        for (Id jobId : jobIds) {
            try {
                System.abortJob(jobId);
            } catch (Exception ex) {
                // Ignore failures and continue
            }
        }
    }
}