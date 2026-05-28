/**
 * @description JavaScript controller for the caseCreate LWC component (MP-8).
 *              Handles the Product Information section of the Create a Support Case
 *              screen for the Parts Technical Help record type.
 *
 *              Key behaviours:
 *                - Serial Number: triggers findAssetBySerial on Enter / Tab
 *                - Part Number record-picker: triggers getPartDescription on change
 *                - Save button: validates required fields, calls saveCaseAsDraft
 *
 * @author      Suman Saha
 * @story       MP-8
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import findAssetBySerial  from '@salesforce/apex/CaseCreateController.findAssetBySerial';
import getPartDescription from '@salesforce/apex/CaseCreateController.getPartDescription';
import saveCaseAsDraft    from '@salesforce/apex/CaseCreateController.saveCaseAsDraft';

// Static picklist options for No Part Reason (not driven by dynamic query in MP-8)
const NO_PART_REASON_OPTIONS = [
    { label: 'Not Yet Available', value: 'Not Yet Available' },
    { label: 'Unknown Part',      value: 'Unknown Part' },
    { label: 'Other',             value: 'Other' }
];

export default class CaseCreate extends LightningElement {

    // ─── Serial Number ─────────────────────────────────────────────────────────
    assetSerialNumber = '';

    // ─── Asset lookup state ─────────────────────────────────────────────────────
    assetId;
    assetFound = false;

    // ─── Row 1 — Equipment Identity (disabled, auto-populated from Asset) ───────
    brand        = '';
    machineType  = '';
    series       = '';
    modelNumber  = '';

    // ─── Row 2 — Usage Info ─────────────────────────────────────────────────────
    unitOfMeasure  = '';
    machineUsage   = '';
    usageAvailable = false;   // controls Machine Usage editability
    usedWith       = '';      // always editable
    engineSerial   = '';      // display only, not saved to Case

    // ─── Row 3 — Part Information ───────────────────────────────────────────────
    partNumberId    = null;
    partDescription = '';
    noPartReason    = '';

    // ─── After save ─────────────────────────────────────────────────────────────
    caseId     = null;
    caseNumber = '';
    caseStatus = '';

    // ─── UI state ───────────────────────────────────────────────────────────────
    isSaving     = false;
    errorMessage = '';

    // ─── Static options ─────────────────────────────────────────────────────────
    get noPartReasonOptions() {
        return NO_PART_REASON_OPTIONS;
    }

    /** Returns the status to display; falls back to 'New' before any save */
    get displayStatus() {
        return this.caseStatus || 'New';
    }

    // ─── Serial Number handlers ─────────────────────────────────────────────────

    handleSerialChange(event) {
        this.assetSerialNumber = event.detail.value;
    }

    /**
     * Triggers findAssetBySerial on Enter (key 13) or Tab (key 9).
     * Also handles the clear icon (clear button rendered by lightning-input).
     */
    handleSerialKeyDown(event) {
        const key = event.key || event.keyCode;
        if (key === 'Enter' || key === 13 || key === 'Tab' || key === 9) {
            if (this.assetSerialNumber && this.assetSerialNumber.trim() !== '') {
                this._fetchAsset(this.assetSerialNumber.trim());
            }
        }
    }

    /** Clears serial number field and all product info fields */
    handleClearSearch() {
        this.assetSerialNumber = '';
        this._resetProductFields();
    }

    // ─── Machine Usage / Used With handlers ────────────────────────────────────

    handleMachineUsageChange(event) {
        this.machineUsage = event.detail.value;
    }

    handleUsedWithChange(event) {
        this.usedWith = event.detail.value;
    }

    // ─── Part Number handler ────────────────────────────────────────────────────

    /**
     * Fires when the lightning-record-picker value changes.
     * Calls getPartDescription if a record was selected; clears description if removed.
     */
    handlePartChange(event) {
        const recordId = event.detail.recordId;
        this.partNumberId = recordId || null;
        if (recordId) {
            this._fetchPartDescription(recordId);
        } else {
            this.partDescription = '';
        }
    }

    // ─── No Part Reason handler ─────────────────────────────────────────────────

    handleNoPartReasonChange(event) {
        this.noPartReason = event.detail.value;
    }

    // ─── Save handler ───────────────────────────────────────────────────────────

    handleSave() {
        this.errorMessage = '';

        // Client-side required field validation
        if (!this._validateRequiredFields()) {
            return;
        }

        this.isSaving = true;

        // Build Case sObject — only the 11 Product Information fields (TDD §4.4)
        const caseRecord = {
            AssetId:                  this.assetId            || null,
            Brand__c:                 this.brand              || null,
            Machine_Type__c:          this.machineType        || null,
            Series__c:                this.series             || null,
            Model_Number__c:          this.modelNumber        || null,
            Unit_of_Measure__c:       this.unitOfMeasure      || null,
            Machine_Usage__c:         this.machineUsage       || null,
            Part_Number__c:           this.partNumberId       || null,
            Part_Description__c:      this.partDescription    || null,
            No_Causal_Part_Reason__c: this.noPartReason       || null,
            Used_With__c:             this.usedWith           || null
        };

        saveCaseAsDraft({ caseRecord })
            .then(result => {
                this.caseId     = result.caseId;
                this.caseNumber = result.caseNumber;
                this.caseStatus = result.status;
                this._showToast('Success', 'Case saved as Draft. Case Number: ' + result.caseNumber, 'success');
            })
            .catch(error => {
                const msg = error?.body?.message || error?.message || 'An unexpected error occurred.';
                this.errorMessage = msg;
                this._showToast('Error', msg, 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    // ─── Private helpers ────────────────────────────────────────────────────────

    /**
     * Calls findAssetBySerial imperatively and populates product info fields.
     */
    _fetchAsset(serialNumber) {
        findAssetBySerial({ serialNumber })
            .then(result => {
                if (result) {
                    this.assetId        = result.assetId;
                    this.brand          = result.brand          || '';
                    this.machineType    = result.machineType    || '';
                    this.series         = result.series         || '';
                    this.modelNumber    = result.modelNumber    || '';
                    this.unitOfMeasure  = result.unitOfMeasure  || '';
                    this.machineUsage   = result.machineUsage   || '';
                    this.usageAvailable = result.usageAvailable || false;
                    this.engineSerial   = result.engineSerial   || '';
                    this.assetFound     = true;
                    this.errorMessage   = '';
                } else {
                    this._resetProductFields();
                    this.errorMessage = 'No Asset found for the entered serial number.';
                }
            })
            .catch(error => {
                const msg = error?.body?.message || error?.message || 'Error fetching asset data.';
                this.errorMessage = msg;
                this._showToast('Error', msg, 'error');
                this._resetProductFields();
            });
    }

    /**
     * Calls getPartDescription imperatively and populates Part Description field.
     */
    _fetchPartDescription(partId) {
        getPartDescription({ partId })
            .then(description => {
                this.partDescription = description || '';
            })
            .catch(error => {
                const msg = error?.body?.message || error?.message || 'Error fetching part description.';
                this._showToast('Error', msg, 'error');
                this.partDescription = '';
            });
    }

    /**
     * Validates required fields before save.
     * Required: Asset/Serial Number, Brand, Machine Type, Series, Model Number.
     * Shows a toast and sets errorMessage if any required field is empty.
     */
    _validateRequiredFields() {
        const missing = [];
        if (!this.assetSerialNumber || this.assetSerialNumber.trim() === '') {
            missing.push('Asset/Serial Number');
        }
        if (!this.brand || this.brand.trim() === '') {
            missing.push('Brand');
        }
        if (!this.machineType || this.machineType.trim() === '') {
            missing.push('Machine Type');
        }
        if (!this.series || this.series.trim() === '') {
            missing.push('Series');
        }
        if (!this.modelNumber || this.modelNumber.trim() === '') {
            missing.push('Model Number');
        }

        if (missing.length > 0) {
            const msg = 'Required field(s) missing: ' + missing.join(', ');
            this.errorMessage = msg;
            this._showToast('Required Fields', msg, 'error');
            return false;
        }
        return true;
    }

    /**
     * Resets all product-information fields and asset state.
     * Called by Clear Search and when asset lookup returns no result.
     */
    _resetProductFields() {
        this.assetId        = null;
        this.assetFound     = false;
        this.brand          = '';
        this.machineType    = '';
        this.series         = '';
        this.modelNumber    = '';
        this.unitOfMeasure  = '';
        this.machineUsage   = '';
        this.usageAvailable = false;
        this.engineSerial   = '';
        this.usedWith       = '';
        this.partNumberId   = null;
        this.partDescription = '';
        this.noPartReason   = '';
        this.errorMessage   = '';
    }

    /**
     * Fires a ShowToastEvent.
     */
    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
