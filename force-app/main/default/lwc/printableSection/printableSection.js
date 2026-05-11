import { LightningElement,wire, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import jsPDFLibrary from '@salesforce/resourceUrl/jsPDFLibrary';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import NAME_FIELD from "@salesforce/schema/Account.Name";
import PHONE_FIELD from "@salesforce/schema/Account.Phone";
import RATING_FIELD from "@salesforce/schema/Account.Rating";
import TYPE_FIELD from '@salesforce/schema/Account.Type';
import WEBSITE_FIELD from '@salesforce/schema/Account.Website';
import INDUSTRY_FIELD from "@salesforce/schema/Account.Industry";
import ANNUAL_REVENUE from '@salesforce/schema/Account.AnnualRevenue'
import BILLING_STREET_FIELD from '@salesforce/schema/Account.BillingStreet';

const fields = [NAME_FIELD, PHONE_FIELD, TYPE_FIELD, WEBSITE_FIELD, BILLING_STREET_FIELD, RATING_FIELD, INDUSTRY_FIELD, ANNUAL_REVENUE];

export default class PrintableSection extends LightningElement {

    jsPDFInitialized = false;

    @api recordId;
    accountName;
    phone;
    rating;
    type;
    website;
    industry;
    annualRevenue;
    billingStreet;

    @wire(getRecord, {
        recordId: "$recordId",
        fields
    })

    accountData({
        data,
        error
    }) {

        if (data) {
            console.log('data' + JSON.stringify(data))
            this.accountName = getFieldValue(data, NAME_FIELD);
            this.phone = getFieldValue(data, PHONE_FIELD);
            this.rating = getFieldValue(data, RATING_FIELD);
            this.type = getFieldValue(data, TYPE_FIELD);
            this.website = getFieldValue(data, WEBSITE_FIELD);
            this.industry = getFieldValue(data, INDUSTRY_FIELD);
            this.annualRevenue = getFieldValue(data, ANNUAL_REVENUE);
            this.billingStreet = getFieldValue(data, BILLING_STREET_FIELD);
        } else if (error) {
            console.log('Error value parse ' + JSON.stringify(error));
        }

    }
  
    renderedCallback() {
        if (!this.jsPDFInitialized) {
            this.jsPDFInitialized = true;
            loadScript(this, jsPDFLibrary)
                .then(() => {
                    console.log('jsPDF library loaded successfully');
                })
                .catch((error) => {
                    console.error('Error loading jsPDF library', error);
                });
        }
    }

generatePDF() {
        if (this.jsPDFInitialized) {
            try {
                const doc = new window.jspdf.jsPDF();

                doc.text('Account Information', 70, 20);
                //Image in base64 format
                //const imgData = 'base64 format Image';
                //doc.addImage(imgData, 'JPEG', 140, 25, 55, 35);

                doc.line(60, 24, 145, 24);

                doc.setLineWidth(2);
                doc.setFontSize(14)
                //doc.setFont('arial black');

                doc.text('Account Name:', 30, 60);
                doc.text('Type:', 30, 70);
                doc.text('Industry:', 30, 80);
                doc.text('Annual Revenue:', 30, 90);
                doc.text('Website:', 30, 100);
                doc.text('Rating:', 30, 110);
                doc.text('Billing Street:', 30, 120);
                doc.text(this.accountName, 70, 60);
                doc.text(this.type, 70, 70);
                doc.text(this.industry, 70, 80);
                doc.text(this.annualRevenue.toString(), 70, 90);
                doc.text(this.website, 70, 100);
                doc.text(this.rating, 70, 110);
                doc.text(this.billingStreet, 70, 120);
           
                doc.save('AccountInformation.pdf');

            } catch (error) {
                console.log('Error in generating PDF', JSON.stringify(error));
            }
        } else {
            console.error('jsPDF library is not loaded');
        }
    }
}