import { LightningElement, track } from 'lwc';

export default class DynamicDetailsForm extends LightningElement {
    @track fields = [];

    connectedCallback() {
        const text = `1. Full Name2. Property Address3. Loan Number4. Contact Information (Phone Number and/or Email Address)5. Reason for PMI Removal Request6. Current Property Value (if applicable)7. Proof of Property Value (e.g., recent appraisal, if applicable)`;

        // Extract numbered points
        const points = text.match(/\d+\.\s[^\d]+/g);

        // Create fields dynamically
        if (points) {
            this.fields = points.map((point, index) => {
                return { id: index + 1, label: point.substring(3).trim(), value: '' };
            });
        }
    }

    handleInputChange(event) {
        const fieldId = event.target.dataset.id;
        const value = event.target.value;
        this.fields = this.fields.map(field =>
            field.id === parseInt(fieldId) ? { ...field, value: value } : field
        );
    }

    handleSubmit() {
        const jsonData = JSON.stringify(this.fields);
        console.log('Submitted Data:', jsonData);
    }
}