declare module "@salesforce/apex/CISyncController.getCalculatedInsights" {
  export default function getCalculatedInsights(): Promise<any>;
}
declare module "@salesforce/apex/CISyncController.getInsightFields" {
  export default function getInsightFields(param: {ciName: any}): Promise<any>;
}
declare module "@salesforce/apex/CISyncController.initializeMetadata" {
  export default function initializeMetadata(): Promise<any>;
}
declare module "@salesforce/apex/CISyncController.initializeSpecificMetadata" {
  export default function initializeSpecificMetadata(param: {cioDevName: any}): Promise<any>;
}
declare module "@salesforce/apex/CISyncController.getInsightSyncStatus" {
  export default function getInsightSyncStatus(param: {pollingAttempt: any}): Promise<any>;
}
declare module "@salesforce/apex/CISyncController.fullSync" {
  export default function fullSync(param: {ciDevName: any}): Promise<any>;
}
declare module "@salesforce/apex/CISyncController.incrementalSync" {
  export default function incrementalSync(param: {ciDevName: any, fieldDevName: any}): Promise<any>;
}
declare module "@salesforce/apex/CISyncController.incrementalSyncWithSchedule" {
  export default function incrementalSyncWithSchedule(param: {ciDevName: any, fieldDevName: any, scheduleInMin: any}): Promise<any>;
}
