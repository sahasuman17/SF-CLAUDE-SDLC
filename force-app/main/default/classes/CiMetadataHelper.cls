/**
 * @description Manages the processing of Full Sync.
 * Helper class for smartSyncInitializer class to retrieve CI metadata information.
 * @Debanjan Mukherjee
 * @since 2025-06-19
 */
 @SuppressWarnings('PMD')
public class CiMetadataHelper {
    /**
     * @description forced exception for to check failure handling
     */
    public class MetadataServiceException extends Exception {}
    string allCiMetaResponses;
	/**
     * @description - Integration call to Data Cloud to fetch the CIOs
     * @param none - will retrive all CIOs.
     * @exception theException if no CIO found
     */
    public static list<metadata> fetchInsightMetas()
    {
        try{
            String allCiMetaResponses;
            if(Test.isRunningTest())
            {
                StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'ciMetadataProxy' LIMIT 1];
                allCiMetaResponses = sr.Body.toString();
            }
            else
            {
                allCiMetaResponses = SmartSyncService.getAllCioMetadata();
            }
            // Deserialize the JSON string into an Apex class (e.g., MyApexClass)
            ciMetadata objCiMetas = (ciMetadata)JSON.deserialize(allCiMetaResponses, ciMetadata.class);
            // Now you can work with the data in myObject
            // $&
            return objCiMetas.metadata;
        }
        catch(Exception ex)
        {
            throw new MetadataServiceException('Field creation error: ' , ex);
        }
    }
    /**
     * @description - Integration call to Data Cloud to fetch the CIOs
     * @param none - will retrive all CIOs.
     * @exception theException if no CIO found
     */
    public static list<metadata> fetchSpecificInsightMeta(string cioDevName)
    {
        try{
            String allCiMetaResponses;
            if(Test.isRunningTest())
            {
                StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'ciMetadataProxy' LIMIT 1];
                allCiMetaResponses = sr.Body.toString();
            }
            else
            {
                allCiMetaResponses = SmartSyncService.getSpecificCioMetadata(cioDevName);
            }
            // Deserialize the JSON string into an Apex class (e.g., MyApexClass)
            ciMetadata objCiMetas = (ciMetadata)JSON.deserialize(allCiMetaResponses, ciMetadata.class);
            
            return objCiMetas.metadata;
        }
        catch(Exception ex)
        {
            throw new MetadataServiceException('Field creation error: ' , ex);
        }
    }
	/**
     * @description - Integration call to Data Cloud to fetch the CIOs
     * @param none - Wrapper to hold the integration response of CIO metadata.
     * @exception theException if no CIO found
     */
    public class ciMetadata
    {
        public list<metadata> metadata{get;set;}
    }
    // Overloaded method for testing
    @TestVisible
    public static List<metadata> parseInsightMetas(String jsonString) {
        ciMetadata objCiMetas = (ciMetadata)JSON.deserialize(jsonString, ciMetadata.class);
        return objCiMetas.metadata;
    }
	/**
     * @description - Integration call to Data Cloud to fetch the CIOs
     * @param none - Wrapper to hold the integration response of CIO metadata.
     * @exception theException if no CIO found
     */
	public class relationships{
		public String toEntity{get;set;}
		public String fromEntity{get;set;}
	}
	/**
     * @description - Integration call to Data Cloud to fetch the CIOs
     * @param none - Wrapper to hold the integration response of CIO metadata.
     * @exception theException if no CIO found
     */
	public class metadata{
		public list<relationships> relationships{get;set;}
		public list<measures> measures{get;set;}
		public String partitionBy{get;set;}
		public list<dimensions> dimensions{get;set;}
		public datetime latestProcessTime{get;set;}
		public String displayName{get;set;}
		public datetime latestSuccessfulProcessTime{get;set;}
		public String name{get;set;}
	}
	/**
     * @description - Integration call to Data Cloud to fetch the CIOs
     * @param none - Wrapper to hold the integration response of CIO metadata.
     * @exception theException if no CIO found
     */
	public class measures{
		public Boolean rollupable{get;set;}
		public String name{get;set;}
		public String displayName{get;set;}
		public String businessType{get;set;}
		public String type{get;set;}
	}
	/**
     * @description - Integration call to Data Cloud to fetch the CIOs
     * @param none - Wrapper to hold the integration response of CIO metadata.
     * @exception theException if no CIO found
     */
	public class dimensions{
		public String businessType{get;set;}
		public String displayName{get;set;}
		public String type{get;set;}
		public String name{get;set;}
	}

}