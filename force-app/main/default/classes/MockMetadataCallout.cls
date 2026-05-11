/**
 * @name        MockMetadataCallout
 * @description Mock class for simulating Metadata API HTTP callout responses in test context.
 *              Implements HttpCalloutMock for testing HTTP-dependent logic without real callouts.
 * @author      Debanjan Mukherjee
 * @created     05 July 2025
 */
@IsTest
public class MockMetadataCallout implements HttpCalloutMock {
    /**
     * @description Responds with a dummy 200 OK HTTP response with JSON content.
     * @param req The incoming HttpRequest (not used but required by interface).
     * @return A mocked HttpResponse with a simulated Metadata API success body.
     */
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{ "success": true, "message": "Mock response for Metadata API call" }');
        res.setStatusCode(200);
        return res;
    }
}