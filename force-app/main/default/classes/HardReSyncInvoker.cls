/**
 * @description Invocable action to trigger metadata re-initialization for a specific Calculated Insight by developer name.
 */
public with sharing class HardReSyncInvoker {

    /**
     * @description Wrapper input class for Flow invocation containing the Developer Name of the Calculated Insight.
     */
    public class InputWrapper {
        /** @description Developer name of the Calculated Insight to reinitialize. */
        @InvocableVariable(required=true)
        public String cioDevName;
    }

    /**
     * @description Invocable method that calls CISyncController.initializeSpecificMetadata for each provided Developer Name.
     * @param inputList List of input wrappers containing Developer Names of Calculated Insights.
     */
    @InvocableMethod(label='Hard Resync CI Metadata')
    public static void initialize(List<InputWrapper> inputList) {
        for (InputWrapper input : inputList) {
            if (String.isNotBlank(input.cioDevName)) {
                CISyncController.initializeSpecificMetadata(input.cioDevName); 
            }
        }
    }
}