import { LightningElement, api } from 'lwc';
import fetchInsights from '@salesforce/apex/CISyncController.initializeMetadata';
import getInsightSyncStatus from '@salesforce/apex/CISyncController.getInsightSyncStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CiSyncFlowComponent extends LightningElement {
    @api fetchInsightSuccess;

    pollingInterval;
    pollingAttempts = 0;
    maxPollingAttempts = 20; // 10 * 2s = 14s (max 15s wait)

    showSpinner = true;
    hasError = false;
    spinnerMessage = 'Getting Calculated Insight Metadata...';

    connectedCallback() {
        this.startSync();
    }

    startSync() {
        this.showSpinner = true;
        this.hasError = false;
        this.fetchInsightSuccess = false;

        fetchInsights()
            .then(() => {
                this.startPolling();
            })
            .catch(error => {
                this.handleError('Failed to start sync: ' + this.getErrorMessage(error));
            });
    }

    startPolling() {
        this.pollingInterval = setInterval(() => {
            this.pollingAttempts++;

            getInsightSyncStatus({ pollingAttempt: this.pollingAttempts }) // 🔄 pass attempt to bust LDS cache
                .then(status => {
                    if (status === 'Success') {
                        this.showSpinner = false;
                        this.fetchInsightSuccess = true;
                        clearInterval(this.pollingInterval);
                    } else if (status === 'NoData' || status === 'Error') {
                        this.showSpinner = false;
                        this.hasError = true;
                        this.fetchInsightSuccess = false;
                        clearInterval(this.pollingInterval);
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Error',
                            message: 'Error fetching Calculated Insights from Data Cloud',
                            variant: 'error'
                        }));
                    } else {
                        this.spinnerMessage = `Status: ${status}...`;
                    }
                })
                .catch(error => {
                    this.handleError('Polling failed: ' + this.getErrorMessage(error));
                    clearInterval(this.pollingInterval);
                });

            if (this.pollingAttempts >= this.maxPollingAttempts) {
                clearInterval(this.pollingInterval);
                this.handleError('Timed out: No response from Data Cloud.');
            }
        }, 2000); // 🔁 2-second interval
    }

    handleError(msg) {
        this.showSpinner = false;
        this.hasError = true;
        this.fetchInsightSuccess = false;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: msg,
                variant: 'error'
            })
        );
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'Unknown error';
    }

    disconnectedCallback() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
        }
    }
}