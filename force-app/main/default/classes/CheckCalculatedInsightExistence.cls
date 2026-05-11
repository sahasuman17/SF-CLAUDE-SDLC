/**
 * @description Invocable class for Flow to check existence of Calculated_Insight__c records.
 * Returns true if record count > 0, else false.
 *
 * Author: Debanjan Mukherjee
 * Created on: 1 Jul 2025
 */
public with sharing class CheckCalculatedInsightExistence {

    /**
     * @description Invocable method to check if any Calculated_Insight__c records exist.
     * @param requests Not used (kept for invocable compliance)
     * @return List containing one ResultWrapper with isPresent set.
     */
    @InvocableMethod(label='Check Calculated Insight Existence'
                     description='Returns true if Calculated_Insight__c record count > 0')
    public static List<Boolean> checkExistence(List<String> requests) {
        ResultWrapper result = new ResultWrapper();
        try {
            Integer countCI = [SELECT COUNT() FROM Calculated_Insight__c];
            result.isPresent = (countCI > 0);
        } catch (Exception ex) {
            result.isPresent = false;
            // Optionally log the error using a custom logger
        }
        return new List<Boolean>{ result.isPresent };
    }

    /**
     * @description Empty input wrapper to satisfy Flow's requirement for a list input.
     */
    public class EmptyRequest {
        // No input fields required for this use case
    }

    /**
     * @description Output wrapper class to return boolean result to Flow.
     */
    public class ResultWrapper {
        @InvocableVariable(label='Is Present' description='True if records exist')
        public Boolean isPresent;
    }
}