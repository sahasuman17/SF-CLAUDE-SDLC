/**
 * @name        DataCloudIntegrationUtil
 * @description Utility class to handle authentication and callouts to Salesforce Data Cloud APIs.
 * @author      Debanjan Mukherjee
 * @created     20 Jun 2025
 */
public with sharing class DataCloudIntegrationUtil {
    // Cached values for Data Cloud tenant URL and access token
    private static String dcTenantUrl;
    private static String dcAccessToken;
    /**
     * @description Initializes the authentication with Data Cloud if not already cached.
     */
    public static void initAuth() {
        if (String.isBlank(dcTenantUrl) || String.isBlank(dcAccessToken)) {
            List<String> lstTokens = DataCloudAuthService.authenticateWithDataCloud();
            dcTenantUrl = lstTokens[0];
            dcAccessToken = lstTokens[1];
        }
    }

    /**
     * @description Generic method to invoke any Data Cloud API using authenticated credentials.
     * @param httpMethod The HTTP method to use (GET, POST, etc.)
     * @param httpEndPoint The relative endpoint to call (e.g. /api/v2/query)
     * @param httpBody The request body (if any) to send
     * @return HttpResponse The HTTP response returned from Data Cloud
     * @example
     * <code>
     * String method = 'POST';
     * String endpoint = '/api/v2/query';
     * String body = '{"sql":"SELECT field__c FROM object__dlm LIMIT 10"}';
     * HttpResponse response = DataCloudIntegrationUtil.getDataFromDataCloud(method, endpoint, body);
     * </code>
     */
    public static HttpResponse getDataFromDataCloud(String httpMethod, String httpEndPoint, String httpBody) {
        initAuth();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(dcTenantUrl + httpEndPoint);
        req.setMethod(httpMethod);
        req.setHeader('Authorization', dcAccessToken);
        req.setHeader('Content-Type', 'application/json');
        if (String.isNotBlank(httpBody)) {
            req.setBody(httpBody);
        }
        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            return res;
        } catch (Exception ex) {
            throw ex;
        }
    }
}