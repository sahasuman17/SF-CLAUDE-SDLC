/**
 * @name        CreateFlowInvoker
 * @description Utility class to invoke the CreateFlow REST resource.
 * @author      Debanjan Mukherjee
 * @created     2025-06-26
 */
public class CreateFlowInvoker {
    /**
     * @description Custom exception for failures
     */
    public class calloutException extends Exception {}
	/**
     * @description Sends a POST request to Token REST endpoint.
     * @return DataCloudAuthService.TokenResponse wrapper
     */
	public static DataCloudAuthService.TokenResponse authDataCloud()
    {
        DataCloudAuthService.TokenResponse token = DataCloudAuthService.authOnlyCRM();
        if (token == null || String.isBlank(token.access_token) || String.isBlank(token.instance_url)) {
            // $&
            throw new calloutException('Unable to connect to Data Cloud');
        }
        return token;
    }

    /**
     * @description Sends a POST request to deploy a flow via the REST endpoint.
     * @param cioApiName API name of the object.
     * @param fieldApiNames List of field API names to include in the flow.
     */
    public static void invokeFlowDeployment(String cioApiName, List<String> fieldApiNames) {
        DataCloudAuthService.TokenResponse token = authDataCloud();
        String instanceUrl = token.instance_url;                // Already includes https://
        String BEARER_TOKEN = 'Bearer ' + token.access_token;
        String ENDPOINT_PATH = '/services/apexrest/sscdc/createFlow';
        HttpRequest request = new HttpRequest();
        request.setEndpoint(instanceUrl + ENDPOINT_PATH);
        request.setMethod('POST');
        request.setHeader('Authorization', BEARER_TOKEN);
        request.setHeader('Content-Type', 'application/json');

        Map<String, Object> payload = new Map<String, Object>{
            'objectApiName' => cioApiName,
            'fieldApiNames' => fieldApiNames
        };
        request.setBody(JSON.serialize(payload));

        Http http = new Http();
        try {
            HttpResponse response = http.send(request);
            // $&
            // $&
        } catch (Exception ex) {
            // $&
        }
    }
}