import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import findAssetBySerial  from '@salesforce/apex/CaseCreateController.findAssetBySerial';
import getPartDescription from '@salesforce/apex/CaseCreateController.getPartDescription';
import saveCaseAsDraft    from '@salesforce/apex/CaseCreateController.saveCaseAsDraft';

export default class CaseCreate extends LightningElement {

    section1Open = true;
    section2Open = true;

    caseId     = null;
    caseNumber = '';
    caseStatus = 'New';

    serialNumber          = '';
    notApplicableToggle   = false;
    assetFound            = false;
    showSuccessMessage    = false;
    assetId               = undefined;

    brand       = '';
    machineType = '';
    series      = '';
    modelNumber = '';

    unitOfMeasure  = '';
    machineUsage   = '';
    usageAvailable = false;
    usedWith       = '';
    engineSerial   = '';

    partNumberId  = undefined;
    partDescription = '';
    noPartReason  = '';

    get noPartReasonOptions() {
        return [
            { label: 'No Fault Found',  value: 'No Fault Found'  },
            { label: 'Legacy Part',     value: 'Legacy Part'     },
            { label: 'Missing Part',    value: 'Missing Part'    }
        ];
    }

    get section1ChevronIcon() {
        return this.section1Open ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get section2ChevronIcon() {
        return this.section2Open ? 'utility:chevrondown' : 'utility:chevronright';
    }

    toggleSection1() { this.section1Open = !this.section1Open; }
    toggleSection2() { this.section2Open = !this.section2Open; }

    handleNotApplicableToggle(event) { this.notApplicableToggle = event.target.checked; }
    handleSerialNumberChange(event)  { this.serialNumber = event.target.value; }
    handleSerialKeyDown(event)       { if (event.key === 'Enter') { this._searchAsset(); } }
    handleSerialBlur()               { if (this.serialNumber) { this._searchAsset(); } }

    handleClearSearch() {
        this.serialNumber = ''; this.assetId = undefined;
        this.assetFound = false; this.showSuccessMessage = false;
        this.brand = ''; this.machineType = ''; this.series = ''; this.modelNumber = '';
        this.unitOfMeasure = ''; this.machineUsage = ''; this.usageAvailable = false; this.engineSerial = '';
    }

    handleMachineUsageChange(event) { this.machineUsage = event.target.value; }
    handleUsedWithChange(event)     { this.usedWith = event.target.value; }

    handlePartNumberChange(event) {
        const recordId = event.detail.recordId;
        this.partNumberId = recordId || undefined;
        if (recordId) {
            getPartDescription({ partId: recordId })
                .then(description => { this.partDescription = description || ''; })
                .catch(() => { this.partDescription = ''; });
        } else {
            this.partDescription = '';
        }
    }

    handleNoPartReasonChange(event) { this.noPartReason = event.detail.value; }

    handleSave() {
        if (!this._validateMandatoryFields()) { return; }
        const caseRecord = {
            AssetId:                  this.assetId,
            Brand__c:                 this.brand,
            Machine_Type__c:          this.machineType,
            Series__c:                this.series,
            Model_Number__c:          this.modelNumber,
            Unit_of_Measure__c:       this.unitOfMeasure,
            Machine_Usage__c:         this.machineUsage,
            Part_Number__c:           this.partNumberId,
            Part_Description__c:      this.partDescription,
            No_Causal_Part_Reason__c: this.noPartReason,
            Used_With__c:             this.usedWith
        };
        if (this.caseId) { caseRecord.Id = this.caseId; }
        saveCaseAsDraft({ caseRecord })
            .then(result => {
                this.caseId = result.caseId; this.caseNumber = result.caseNumber; this.caseStatus = result.status;
                this._showToast('Success', 'Case saved as Draft.', 'success');
            })
            .catch(error => {
                const message = (error && error.body && error.body.message) ? error.body.message : 'An unexpected error occurred.';
                this._showToast('Error', message, 'error');
            });
    }

    handleCancel() {
        this.caseId = null; this.caseNumber = ''; this.caseStatus = 'New';
        this.serialNumber = ''; this.notApplicableToggle = false;
        this.assetFound = false; this.showSuccessMessage = false; this.assetId = undefined;
        this.brand = ''; this.machineType = ''; this.series = ''; this.modelNumber = '';
        this.unitOfMeasure = ''; this.machineUsage = ''; this.usageAvailable = false;
        this.usedWith = ''; this.engineSerial = '';
        this.partNumberId = undefined; this.partDescription = ''; this.noPartReason = '';
    }

    _searchAsset() {
        if (!this.serialNumber) { return; }
        findAssetBySerial({ serialNumber: this.serialNumber })
            .then(result => {
                if (result) {
                    this.assetId = result.assetId;
                    this.brand = result.brand || ''; this.machineType = result.machineType || '';
                    this.series = result.series || ''; this.modelNumber = result.modelNumber || '';
                    this.unitOfMeasure = result.unitOfMeasure || ''; this.machineUsage = result.machineUsage || '';
                    this.usageAvailable = result.usageAvailable || false; this.engineSerial = result.engineSerial || '';
                    this.assetFound = true; this.showSuccessMessage = true;
                } else {
                    this.assetId = undefined; this.assetFound = false; this.showSuccessMessage = false;
                    this.brand = ''; this.machineType = ''; this.series = ''; this.modelNumber = '';
                    this.unitOfMeasure = ''; this.machineUsage = ''; this.usageAvailable = false; this.engineSerial = '';
                }
            })
            .catch(() => { this.assetFound = false; this.showSuccessMessage = false; });
    }

    _validateMandatoryFields() {
        const missing = [];
        if (!this.serialNumber) missing.push('Asset/Serial Number');
        if (!this.brand)        missing.push('Brand');
        if (!this.machineType)  missing.push('Machine Type');
        if (!this.series)       missing.push('Series');
        if (!this.modelNumber)  missing.push('Model Number');
        if (missing.length > 0) {
            this._showToast('Required Fields Missing', 'Please fill in required fields: ' + missing.join(', '), 'error');
            return false;
        }
        return true;
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
