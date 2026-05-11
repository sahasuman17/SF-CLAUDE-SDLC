import { LightningElement, wire, track } from 'lwc';
import { subscribe, onError } from 'lightning/empApi';
import { refreshApex } from '@salesforce/apex';
import getCalculatedInsights from '@salesforce/apex/CISyncController.getCalculatedInsights';
import getInsightFields from '@salesforce/apex/CISyncController.getInsightFields';
import initializeMetadata from '@salesforce/apex/CISyncController.initializeMetadata';
import fullSync from '@salesforce/apex/CISyncController.fullSync';
import incrementalSync from '@salesforce/apex/CISyncController.incrementalSync';

export default class SmartSyncConsole extends LightningElement {
    @track calculatedInsightOptions = [];
    @track keyFieldOptions = [];
    @track selectedInsight;
    @track selectedKeyField;
    @track processingPhase = '';
    @track processingStatus = '';
    @track processingError = '';
    @track fullSyncDone=false;
    insightMap = new Map();
    disableKeyField = true;
    disableFullSync = true;
    disableIncrementalSync = true;

    wiredInsightsResult;
    channelName = '/event/SmartSync_Event__e';
    subscription = {};
    get showProcessingError() {
        return this.processingError && this.processingError.toLowerCase() !== 'success';
    }

    @wire(getCalculatedInsights)
    wiredInsights(result) {
        this.wiredInsightsResult = result;
        const { data, error } = result;

        if (data) {
            this.calculatedInsightOptions = [];
            this.insightMap.clear();

            let errorRecord = null;
            const validOptions = [];

            data.forEach((rec) => {
                this.insightMap.set(rec.Developer_Name__c, rec);
                if (rec.Developer_Name__c === 'Initialization_Error') {
                    errorRecord = rec;
                } else {
                    validOptions.push({
                        label: rec.displayName__c,
                        value: rec.Developer_Name__c
                    });
                }
            });

            if (validOptions.length > 0) {
                this.calculatedInsightOptions = validOptions;
                this.helpMessage='Ready for Sync. Please choose a Calculated Insight';
            } else if (errorRecord) {
                this.processingStatus = errorRecord.Data_Process_Error__c;
                this.processingError = errorRecord.Data_Process_Error__c;
            }
        }

        if (error) {
            this.processingError = error.body?.message || 'Unknown error';
        }
    }

    connectedCallback() {
        this.registerPlatformEvent();
         this.registerErrorHandler();
    }

    registerPlatformEvent() {
        subscribe(this.channelName, -1, (response) => {
            const payload = response?.data?.payload;
            if (payload) {
                this.processingPhase = payload.Phase__c;
                this.processingStatus = payload.Status__c;
                this.processingError = payload.Processing_Error__c;

                if (payload.Phase__c == 'Initialize' && payload.Status__c == 'Success') {
                    this.disableFullSync = false;
                    refreshApex(this.wiredInsightsResult);
                }
            }
        }).then(response => {
            this.subscription = response;
        });

        onError(error => {
            this.processingError = 'Platform event error: ' + JSON.stringify(error);
        });
    }

    handleInsightChange(event) {
        this.selectedInsight = event.detail.value;
        this.disableKeyField = false;
        this.disableIncrementalSync = true;
        this.keyFieldOptions = [];
        this.fullSyncDone = this.insightMap.get(this.selectedInsight).Data_Sync_Done__c;
        getInsightFields({ ciName: this.selectedInsight })
            .then((result) => {
                this.keyFieldOptions = result.map(field => {
                    return {
                        label: field.displayName__c,
                        value: field.Name
                    };
                });
                this.disableFullSync = false;
            })
            .catch((error) => {
                this.processingError = error.body?.message || 'Unknown error';
            });
    }

    handleKeyFieldChange(event) {
        this.selectedKeyField = event.detail.value;
        this.disableIncrementalSync = false;
    }

    handleInitialize() {
        this.processingPhase = 'Initialize';
        this.processingStatus = 'In-Progress';
        this.processingError = '';
        initializeMetadata().catch((error) => {
            this.processingError = error.body?.message || 'Unknown error';
        });
    }

    handleFullSync() {
        this.processingPhase = 'Syncing';
        this.processingStatus = 'In Progress';
        this.processingError = '';
        this.fullSyncDone =false;
        if (this.selectedInsight) {
            fullSync({ ciDevName: this.selectedInsight })
                .catch((error) => {
                    this.processingError = error.body?.message || 'Unknown error';
                });
        }
    }

    handleIncrementalSync() {
        this.processingPhase = 'Syncing';
        this.processingStatus = 'In Progress';
        this.processingError = '';
        if (this.selectedInsight && this.selectedKeyField) {
            incrementalSync({
                ciDevName: this.selectedInsight,
                fieldDevName: this.selectedKeyField
            }).catch((error) => {
                this.processingError = error.body?.message || 'Unknown error';
            });
        }
    }
    get showProcessingError() {
        return this.processingError && this.processingError.toLowerCase() !== 'success';
    }

    get helpMessage() {
        if (!this.calculatedInsightOptions || this.calculatedInsightOptions.length === 0) {
            return 'As a first step please click on Connect to Data Cloud';
        } else if (this.showProcessingError) {
            return 'There are issues during sync. Please refer the processing error for more details';
        }
        else if(this.calculatedInsightOptions.length>0)
        {
            if(this.fullSyncDone || (this.processingPhase=='Full Sync' && this.processingStatus=='Success'))
            {
                this.fullSyncDone =true;
                return 'Ready for Incremental Sync.Please choose one Key & click on Incremental Sync';
            }else{
                return 'Ready for Sync.Please choose one caluclated insight & click on Full Sync';
            }
        }

    }
    set helpMessage(theMessage)
    {
        this.helpMessage = theMessage;
    }
    registerErrorHandler() {
        onError((error) => {
            const err = error?.error || '';

            if (err && err.includes('403::Unknown client')) {
                console.warn('EMP reconnect warning: ', err);

                // Re-subscribe if the current subscription was lost
                if (!this.subscription) {
                    console.log('Re-subscribing to platform event channel...');
                    this.subscribeToPlatformEvent();
                }
            } else {
                // Log other errors (optional: display to user)
                console.error('EMP API Error: ', JSON.stringify(error));
            }
        });
    }
}