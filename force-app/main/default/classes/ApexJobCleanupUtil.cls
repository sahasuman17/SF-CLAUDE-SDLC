/**
 * @description     Utility class to abort incomplete Apex jobs and scheduled jobs properly.
 *                  Prevents aborting scheduled jobs via AsyncApexJob.Id (which throws an error).
 * @author          Debanjan Mukherjee
 * @createdDate     07 July 2025
 */
public class ApexJobCleanupUtil {

    /**
     * Aborts all AsyncApexJobs that are not ScheduledApex and are still in progress.
     */
    public static void abortAsyncJobs() {
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status
            FROM AsyncApexJob
            WHERE Status IN ('Queued', 'Processing', 'Preparing', 'Holding')
            AND JobType != 'ScheduledApex'
        ];

        for (AsyncApexJob job : jobs) {
            try {
                System.abortJob(job.Id);
            } catch (Exception ex) {
                // Silently continue on error
            }
        }
    }

    /**
     * Aborts all scheduled Apex jobs using CronTrigger.
     */
    public static void abortScheduledJobs() {
        List<CronTrigger> scheduled = [
            SELECT Id
            FROM CronTrigger
            WHERE State = 'WAITING'
        ];

        for (CronTrigger ct : scheduled) {
            try {
                System.abortJob(ct.Id);
            } catch (Exception ex) {
                // Silently continue on error
            }
        }
    }

    /**
     * Abort both Async and Scheduled Apex jobs.
     */
    public static void abortAllJobs() {
        abortAsyncJobs();
        abortScheduledJobs();
    }
}