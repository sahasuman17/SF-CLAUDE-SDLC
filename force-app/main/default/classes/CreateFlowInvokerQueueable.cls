/**
 * @name        CreateFlowInvoker
 * @description Queueable wrapper to invoke SSCDC_CreateFlowInvoker asynchronously.
 * @author      Debanjan Mukherjee
 * @created     2025-06-26
 */
public class CreateFlowInvokerQueueable implements Queueable,Database.AllowsCallouts {
    private final String cioApiName;
    private final List<String> fieldApiNames;
    /**
     * @description Constructor for CreateFlowInvokerQueueable.
     * @param cioApiName API name of the Calculated Insight Object (without __c suffix).
     * @param fieldApiNames List of API names of the Insight Fields to be processed.
     */
    public CreateFlowInvokerQueueable(String cioApiName, List<String> fieldApiNames) {
        this.cioApiName = cioApiName;
        this.fieldApiNames = fieldApiNames;
    }
    /**
     * @description Queueable execution that delegates to CreateFlowInvoker.
     * @param context Queueable context.
     */
    public void execute(QueueableContext context) {
        CreateFlowInvoker.invokeFlowDeployment(cioApiName, fieldApiNames);
    }
}