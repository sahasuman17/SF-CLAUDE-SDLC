public class JsonSanitizer {
    /**
     * Converts a pseudo-JSON string (with unquoted keys/values and numeric commas)
     * into a Map<String, String>.
     *
     * @param rawInput A malformed string like:
     *        {revenue_across_duplicate_accounts__c: 740,001, account__c: Edge Communications1}
     * @return A map of key-value pairs
     */
    public static Map<String, String> extractKeyValueMap(String rawInput) {
        Map<String, String> jsonMap = new Map<String, String>();
        String prevKey = null;

        // Trim outer braces
        String content = rawInput.trim();
        if (content.startsWith('{') && content.endsWith('}')) {
            content = content.substring(1, content.length() - 1);
        }

        // Split on commas — but be aware values like "740,001" include commas
        List<String> parts = content.split(',');

        for (String part : parts) {
            if (part.contains(':')) {
                List<String> keyValue = part.split(':', 2);
                if (keyValue.size() == 2) {
                    String key = keyValue[0].trim();
                    String value = keyValue[1].trim();

                    key = key.replaceAll('[^\\w__]+', '');
                    jsonMap.put(key, value);
                    prevKey = key;
                }
            } else if (prevKey != null) {
                // Handle the case where a value had a comma in it (e.g. 740,001)
                String existing = jsonMap.get(prevKey);
                jsonMap.put(prevKey, existing + ',' + part.trim());
            }
        }

        return jsonMap;
    }
}