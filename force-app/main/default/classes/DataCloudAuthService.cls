/**
 * @name        DataCloudAuthService
 * @description Service class for authenticating with Salesforce CRM and Data Cloud using JWT and tenant token exchange.
 * @author      Debanjan Mukherjee
 * @created     20 Jun 2025
 */
public with sharing class DataCloudAuthService {
    /**
     * @description Container class for parsing token response.
     */
    public class TokenResponse {
        /**
        * @description token to connect - will be leverage from all callouts
        */
        public String access_token;
        /**
        * @description The instance specific URL - will be leverage from all callouts
        */
        public String instance_url;
        /**
        * @description urls to connect - will be leverage from all callouts
        */
        public Map<String, Object> urls;
    }
    /**
    * @description Retrieves Data Cloud tenant token using CRM access token.
    * @param crmHostAccessToken The access token from Salesforce CRM.
    * @param crmHostInstanceUrl The instance URL of Salesforce CRM.
    * @param dataspace Optional dataspace parameter for Data Cloud.
    * @return List<String> containing instance URL and bearer token.
    * @throws CalloutException if the token exchange fails.
     */
    public static List<String> getDataCloudTenantToken(String crmHostAccessToken, String crmHostInstanceUrl, String dataspace) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        HttpResponse res;

        String tenantTokenUrl = crmHostInstanceUrl + getConfigValue('DataCloud_Token_Endpoint'); // e.g. '/services/a360/token'

        req.setEndpoint(tenantTokenUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body = 'grant_type=' + getConfigValue('Grant_Type_CDP') +
                      '&subject_token=' + EncodingUtil.urlEncode(crmHostAccessToken, 'UTF-8') +
                      '&subject_token_type=' + getConfigValue('Subject_Token_Type');

        if (String.isNotBlank(dataspace)) {
            body += '&dataspace=' + dataspace;
        }
        req.setBody(body);
        res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Data Cloud token exchange failed: ' + res.getBody());
        }
        TokenResponse tokenResponse = (TokenResponse) JSON.deserialize(res.getBody(), TokenResponse.class);
        List<String> tokens = new List<String>{
            'https://' + tokenResponse.instance_url,
            'Bearer ' + tokenResponse.access_token
        };
        return tokens;
    }
    /**
     * @description Authenticates with Salesforce CRM using JWT and retrieves Data Cloud token.
     * @return List<String> containing instance URL and bearer token.
     * @throws CalloutException if the JWT token generation fails or Data Cloud token exchange fails
     */
    public static List<String> authenticateWithDataCloud() {
        String jwt = generateJwt();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(getConfigValue('CRM_JWT_Endpoint')); // e.g. 'https://login.salesforce.com/services/oauth2/token'
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=' + getConfigValue('JWT_Grant_Type') + '&assertion=' + EncodingUtil.urlEncode(jwt, 'UTF-8'));

        Http http = new Http();
        TokenResponse token;
        if(!Test.isRunningTest())
        {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() != 200) {
                throw new CalloutException('JWT token generation failed: ' + res.getBody());
            }
        	token = (TokenResponse) JSON.deserialize(res.getBody(), TokenResponse.class);
        }else
        {
            TokenResponse mockToken = new TokenResponse();
            mockToken.access_token = 'dummy_token';
            mockToken.instance_url = 'https://test.salesforce.com';
            mockToken.urls = new Map<String, Object>{
                'rest' => 'https://test.salesforce.com/services/data/v57.0/',
                'query' => 'https://test.salesforce.com/services/data/v57.0/query'
            };
        	token = mockToken;
        }
        return getDataCloudTenantToken(token.access_token, token.instance_url, '');
    }
    /**
     * @description Authenticates with Salesforce CRM using JWT and retrieves Data Cloud token.
     * @return TokenResponse containing access token and instance URL.
     * @throws CalloutException if the JWT token generation fails.
     */
    public static TokenResponse authOnlyCRM() {
        String jwt = generateJwt();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(getConfigValue('CRM_JWT_Endpoint')); // e.g. 'https://login.salesforce.com/services/oauth2/token'
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=' + getConfigValue('JWT_Grant_Type') + '&assertion=' + EncodingUtil.urlEncode(jwt, 'UTF-8'));

        Http http = new Http();
        if (Test.isRunningTest()) {
            TokenResponse mockToken = new TokenResponse();
            mockToken.access_token = 'dummy_token';
            mockToken.instance_url = 'https://test.salesforce.com';
            mockToken.urls = new Map<String, Object>{
                'rest' => 'https://test.salesforce.com/services/data/v57.0/',
                'query' => 'https://test.salesforce.com/services/data/v57.0/query'
            };
            return mockToken;
        }
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('JWT token generation failed: ' + res.getBody());
        }

        TokenResponse token = (TokenResponse) JSON.deserialize(res.getBody(), TokenResponse.class);
        return token;
    }
    /**
     * @description Generates a JWT token for authentication.
     * @return String containing the generated JWT token.
     * @throws CalloutException if the JWT generation fails.
     */
    private static String generateJwt() {
        Long now = DateTime.now().getTime() / 1000;
        Long exp = now + 300;

        Map<String, Object> header = new Map<String, Object>{
            'alg' => 'RS256',
            'typ' => 'JWT'
        };

        Map<String, Object> claims = new Map<String, Object>{
            'iss' => getConfigValue('Consumer_Key'),
            'sub' => getConfigValue('JWT_Username'),
            'aud' => getConfigValue('JWT_Audience'),
            'exp' => exp
        };

        String encodedHeader = base64UrlSafe(JSON.serialize(header));
        String encodedClaims = base64UrlSafe(JSON.serialize(claims));
        String token = encodedHeader + '.' + encodedClaims;
        String encodedSignature;
		if (Test.isRunningTest()) {
            // Return dummy JWT for testing
            encodedSignature = 'dummy.header.payload.dummy_signature';
        }else
        {
            Blob signature = Crypto.signWithCertificate('RSA-SHA256', Blob.valueOf(token), getConfigValue('Certificate_Name'));
            encodedSignature = base64UrlSafe(signature);
        }
        return token + '.' + encodedSignature;
    }
    /**
     * @description Encodes a string or Blob to Base64 URL-safe format.
     * @param input The input string or Blob to encode.
     * @return String containing the Base64 URL-safe encoded value.
     */
    private static String base64UrlSafe(String input) {
        return EncodingUtil.base64Encode(Blob.valueOf(input))
            .replace('+', '-')
            .replace('/', '_')
            .replaceAll('=+$', '');
    }
    /**
     * @description Encodes a Blob to Base64 URL-safe format.
     * @param input The Blob to encode.
     * @return String containing the Base64 URL-safe encoded value.
     */
    private static String base64UrlSafe(Blob input) {
        return EncodingUtil.base64Encode(input)
            .replace('+', '-')
            .replace('/', '_')
            .replaceAll('=+$', '');
    }
    /**
     * @description Retrieves configuration value from Generic_Key_Value__mdt.
     * @param keyName The key name to retrieve the value for.
     * @return String containing the configuration value.
     */
    @TestVisible private static Map<String, String> testConfigOverrides = new Map<String, String>();
    private static String getConfigValue(String keyName) {
        if (Test.isRunningTest() && testConfigOverrides.containsKey(keyName)) {
            return testConfigOverrides.get(keyName);
        }
        Generic_Key_Value__mdt config = [
            SELECT Value__c FROM Generic_Key_Value__mdt WHERE Key__c = :keyName LIMIT 1
        ];
        return config != null ? config.Value__c : '';
    }
}