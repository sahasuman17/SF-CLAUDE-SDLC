import { LightningElement, wire, api } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

//import RICH_TEXT_FIELD from '@salesforce/schema/loan_applicant__c';

const SUMMARY_FIELDS = 'Account.Anomalies_Summary__c';
export default class DocsValidationInsight extends LightningElement {
  @api recordId;
  richTextContent;
  formattedInsights;


  @wire(getRecord, { recordId: '$recordId', fields: [SUMMARY_FIELDS] })
  wiredLoan({ error, data }) {//console.log('RecordID'+data);
    try{
        if (data) {
        this.richTextContent = getFieldValue(data, SUMMARY_FIELDS);
        this.processDescription(this.richTextContent);
        //console.log('Rich Text Content:', this.richTextContent);
        } else if (error) {
        console.error('Error loading loan record:', error);
        }
    } catch (error) {
        this.richTextContent ='No document Available';
        this.processDescription(this.richTextContent);
    }
  }

    processDescription(text) {
        this.positiveIndicators = [];
        this.redFlags = [];
        text = text.replace(/\*\*(.+?)\*\*/g, '### $1');
        const lines = text.split(/(?:###|\*\*)/).filter(line => line.trim() !== '');
console.log('lines**'+lines);
        lines.forEach(section => {
            if (section.includes('Positive Indicators')) {
                const indicators = section.split(/-(?!\*)|(?:\*\s)/).slice(1).map(s => s.trim()).filter(s => s !== '');
                indicators.forEach(indicator => {
                    this.positiveIndicators.push({
                        id: crypto.randomUUID(),
                        text: this.escapeHTML(indicator.replace(/&quot;/g, '').replace(/^-/, '').trim()) // Remove the emoji and escape
                    });
                });
            } else if (section.includes('Red Flags')) {
                const flags = section.split('-').slice(1).map(s => s.trim()).filter(s => s !== '');
                flags.forEach(flag => {
                    this.redFlags.push({
                        id: crypto.randomUUID(),
                        text: (flag.replace(/^-/, '').trim().replace(/^([^:]+):/, (_, match) => `<strong>${match.trim()}</strong>:`)) // Remove the emoji and escape
                    });
                });
            }
        });
    }

   escapeHTML = (str) => {
    if (typeof str !== 'string') return str;
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
};
}