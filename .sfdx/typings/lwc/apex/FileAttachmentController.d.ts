declare module "@salesforce/apex/FileAttachmentController.getFileData" {
  export default function getFileData(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/FileAttachmentController.setRollupFlagOnContentVersion" {
  export default function setRollupFlagOnContentVersion(param: {contentDocumentIds: any}): Promise<any>;
}
declare module "@salesforce/apex/FileAttachmentController.deleteFile" {
  export default function deleteFile(param: {contentDocumentId: any, recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/FileAttachmentController.linkFilesToRecord" {
  export default function linkFilesToRecord(param: {sourceRecordId: any, targetRecordId: any, contentDocumentIds: any}): Promise<any>;
}
