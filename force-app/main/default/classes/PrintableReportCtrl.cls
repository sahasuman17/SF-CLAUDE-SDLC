/**
* @File Name : PrintableReportCtrl.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : September 16, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 16, 2025 |   | Initial Version
**/

public with sharing class PrintableReportCtrl {
    public String htmlContent { get; set; }

    public PrintableReportCtrl() {
        // Get the value from the query string parameter “htmlContent”
        htmlContent = ApexPages.currentPage().getParameters().get('htmlContent');
    }
}