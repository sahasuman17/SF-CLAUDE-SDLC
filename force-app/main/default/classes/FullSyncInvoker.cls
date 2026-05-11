/**
 * @description   Invocable Apex class to trigger Full Sync for a given Calculated Insight.
 *                Designed to be used as a Flow Action that calls CISyncController.fullSync.
 * @author        Debanjan Mukherjee
 * @createdDate   07 July 2025
 */
public with sharing class FullSyncInvoker {
    /**
     * @description Input class to accept CI Developer Name from Flow.
     */
    public class Input {
        /**
         * Developer Name of the Calculated Insight.
         */
        @InvocableVariable(required=true)
        public String ciName;
    }
    /**
     * @description Invocable method to run CISyncController.fullSync for the specified CI Developer Name.
     * @param input List of input objects containing ciName
     */
    @InvocableMethod(label='Run Full Sync' description='Triggers full sync for a specified Calculated Insight.')
    public static void invokeFullSync(List<Input> input) {
        if (input == null || input.isEmpty() || String.isBlank(input[0].ciName)) {
            // Flow should enforce required input, but validate defensively
            return;
        }

        try {
            CISyncController.fullSync(input[0].ciName);
        } catch (Exception ex) {
            ErrorLogger.logErrorFromException(
                'High',
                'FullSyncInvoker',
                'invokeFullSync',
                ex,
                'Failed to execute full sync for ' + input[0].ciName
            );
        }
    }
}