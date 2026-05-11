/**
 * @name        ErrorLogger
 * @description Utility class for logging errors in Salesforce.
 *              It provides methods to log errors with different severity levels (Low, Medium, High)
 *              asynchronously using the Error_Log__c custom object.
 *              The class is designed to be PMD and Salesforce Code Analyzer (SCA) compliant.
 *              It includes methods to log errors from exceptions, with the ability to specify custom messages.
 *              The logging is done asynchronously using the @future annotation to avoid blocking the main thread.
 *              The class also includes a custom exception for testing purposes.
 *              The main method to insert an error log is private and handles the creation of the Error_Log__c record.
 *              The class is designed to be used in a larger system where exceptions must be logged for monitoring and debugging purposes.
 *              It is intended to be used by developers to log errors in a consistent manner across the application.
 *              The class is marked with "with sharing" to respect the sharing rules of the current user.
 *              The class includes methods to log errors with different severity levels, allowing for flexible error handling based on the context of the error.
 * @author      Debanjan Mukherjee
 * @created     20 Jun 2025
 */
public with sharing class ErrorLogger {
    /**
     *@description Logs an error with LOW severity level.
     * @param ex The exception to be logged.
    * @param customMessage A custom message provided by the caller.
     * Logs an error with LOW severity level asynchronously.
     * Example usage: ErrorLogger.logLowErrorAsync(new MyException(), 'This is a low severity error');
     */
    public static void logLowErrorAsync(Exception ex, String customMessage) {
        logErrorFromExceptionAsync('Low', ex, customMessage);
    }
    /**
     * @description Custom exception for testing purposes.
     * Custom exception class for testing purposes.
     * This can be used to simulate exceptions in unit tests.
     */
	public class CustomException extends Exception {}
    /**
    *@description Logs an error with MEDIUM severity level.
    * @param ex The exception to be logged.
    * @param customMessage A custom message provided by the caller.
    * Logs an error with MEDIUM severity level asynchronously.
    * Example usage: ErrorLogger.logMediumErrorAsync('This is a medium severity error', new MyException());
    */
    public static void logMediumErrorAsync(Exception ex, String customMessage) {
        logErrorFromExceptionAsync('Medium', ex, customMessage);
    }
    /**
    * @description Logs an error with HIGH severity level.
    * @param ex The exception to be logged.
    * @param customMessage A custom message provided by the caller.
    * Logs an error with HIGH severity level asynchronously.
    * Example usage: ErrorLogger.logHighErrorAsync('This is a high severity error', new MyException());
    */
    public static void logHighErrorAsync(Exception ex, String customMessage) {
        logErrorFromExceptionAsync('High', ex, customMessage);
    }
    /**
     * @description Private method to extract information from the exception and prepare it for logging asynchronously.
     * @param severityLevel The level of severity ('Low', 'Medium', 'High').
     * @param ex The exception to be parsed.
     * @param customMessage A custom message provided by the caller.
     */
    private static void logErrorFromExceptionAsync(String severityLevel, Exception ex, String customMessage) {
        String className = 'Unknown';
        String methodName = 'Unknown';
        enqueueErrorLogAsync(severityLevel, className, methodName, ex.getLineNumber(), ex.getMessage(), customMessage);
    }
    /**
     * @description Private method to extract information from the exception and prepare it for logging asynchronously.
     * @param severityLevel The level of severity ('Low', 'Medium', 'High').
     * @param className The name of the class where the exception occurred.
     * @param methodName The name of the method where the exception occurred.
     * @param ex The exception to be parsed.
     * @param customMessage A custom message provided by the caller.
     */
    public static void logErrorFromExceptionAsync(String severityLevel,string className,string methodName, Exception ex, String customMessage){
        enqueueErrorLogAsync(severityLevel, className, methodName, ex.getLineNumber(), ex.getMessage(), customMessage);
    }
    /**
     * @description Logs an error with LOW severity level from an exception.
     * @param severityLevel The level of severity ('Low', 'Medium', 'High').
     * @param className The name of the class where the error occurred.
     * @param methodName The name of the method where the error occurred.
     * @param ex The exception to be logged.
     * @param customMessage A custom message provided by the caller.
     */
    public static void logErrorFromException(String severityLevel,string className,string methodName, Exception ex, String customMessage) {
        if(null != ex)
        {
        	logError( className, methodName, ex.getLineNumber(), customMessage, ex.getMessage(),severityLevel);
        }
        else
        {
            logError( className, methodName, 0, customMessage, '','Info');
        }
    }
    /**
     * @description Enqueues an error log asynchronously using the @future annotation.
     * @param severityLevel The level of severity ('Low', 'Medium', 'High').
     * @param className The name of the class where the error occurred.
     * @param methodName The name of the method where the error occurred.
     * @param lineNumber The line number where the error occurred.
     * @param exceptionDetails A string representation of the exception details.
     * @param customMessage A custom message provided by the caller.
     */
    @future
    private static void enqueueErrorLogAsync(String severityLevel, String className, String methodName, Integer lineNumber, String exceptionDetails, String customMessage) {
        logError(className, methodName, lineNumber, customMessage, exceptionDetails, severityLevel);
    }
    /**
     * @description Main method to insert an error log in Error_Log__c object.
     * @param className Name of the class where the error occurred.
     * @param methodName Name of the method where the error occurred.
     * @param lineNumber Line number where the error occurred.
     * @param errorMessage Error message to be logged.
     * @param exceptionDetails A string representation of the exception details.
     * @param severityLevel The severity level of the error ('Low', 'Medium', 'High').
     */
    private static void logError(String className, String methodName, Integer lineNumber, String errorMessage, String exceptionDetails, String severityLevel) {
        Error_Log__c errorLog = new Error_Log__c();
        errorLog.ClassName__c = className;
        errorLog.MethodName__c = methodName;
        errorLog.LineNumber__c = lineNumber;
        errorLog.ErrorMessage__c = errorMessage;
        errorLog.ExceptionThrown__c = exceptionDetails;
        errorLog.Status__c = 'New';
        errorLog.SeverityLevel__c = severityLevel;
        insert errorLog;
    }
}