/**
 * @description   Invocable class for triggering Incremental Sync with a schedule delay.
 *                Calls CISyncController.incrementalSyncWithSchedule.
 *                Accepts Developer Name, Field Name, and Delay (minutes) from Flow.
 *                Handles errors using ErrorLogger.logErrorFromException.
 * @author        Debanjan Mukherjee
 * @createdDate   07 July 2025
 */
public with sharing class IncrementalSyncInvoker {

    /**
     * @description Input wrapper class for Flow parameters.
     */
    public class Input {
        @InvocableVariable(required=true)
        public String ciDevName;

        @InvocableVariable(required=true)
        public String fieldDevName;

        @InvocableVariable(required=true)
        public Integer scheduleInMin;
    }

    /**
     * @description Flow-invoked method to trigger incremental sync with delay.
     *
     * @param input List of Flow inputs with ciDevName, fieldDevName, and scheduleInMin
     */
    @InvocableMethod(label='Run Incremental Sync' description='Triggers incremental sync for a specified Calculated Insight.')
    public static void invokeIncrementalSync(List<Input> input) {
        if (input == null || input.isEmpty()) {
            return;
        }
        if (String.isBlank(input[0].ciDevName) || String.isBlank(input[0].fieldDevName) || input[0].scheduleInMin == null) {
            return;
        }
        try {
            CISyncController.incrementalSyncWithSchedule(
                input[0].ciDevName,
                input[0].fieldDevName,
                String.valueOf(input[0].scheduleInMin)
            );
        } catch (Exception ex) {
            ErrorLogger.logErrorFromException(
                'High',
                'IncrementalSyncInvoker',
                'invokeIncrementalSync',
                ex,
                'Failed to schedule incremental sync'
            );
        }
    }
}