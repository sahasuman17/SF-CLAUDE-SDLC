/**
 * @description   Invocable class to check if a custom object named [ciDevName__c] exists in the org.
 *                Accepts a single Flow input parameter for ciDevName and returns true/false.
 *                Designed to be used in Screen or Autolaunched Flows.
 * @author        Debanjan Mukherjee
 * @createdDate   07 July 2025
 */
public with sharing class CheckCustomObjectExistsInvoker {

    /**
     * @description Flow input wrapper.
     */
    public class Input {

        /**
         * @description Developer Name of the Calculated Insight (e.g., 'My_Insight' will become 'My_Insight__c')
         */
        @InvocableVariable(required=true)
        public String ciDevName;
    }

    /**
     * @description Flow output wrapper.
     */
    public class Output {
        /**
         * @description  True if the object exists (ciDevName__c), otherwise false.
         */
        @InvocableVariable
        public Boolean objectExists=false;
    }

    /**
     * @description Invocable method to check whether a custom object [ciDevName__c] exists in the org.
     *
     * @param input A single-item list containing ciDevName input
     * @return A single-item list containing a boolean flag indicating object existence
     */
    @InvocableMethod(label='Check object exists' description='Checks whether a custom object exists and returns true or false.')
    public static List<Output> checkObjectExists(List<Input> input) {
        List<Output> results = new List<Output>();
        Output output = new Output();

        try {
            if (input != null && !input.isEmpty() && !String.isBlank(input[0].ciDevName)) {
                String fullObjectName = input[0].ciDevName + '__c';
                output.objectExists = Schema.getGlobalDescribe().containsKey(fullObjectName);
                 String Query = 'Select Id from '+fullObjectName+ ' Limit 1';
                 sObject s = Database.query(Query);
            } else {
                output.objectExists = false;
            }
        } catch (Exception ex) {
            output.objectExists = false;
        }

        results.add(output);
        return results;
    }
}