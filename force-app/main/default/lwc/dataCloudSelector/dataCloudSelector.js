import { LightningElement } from 'lwc';

export default class DataCloudSelector extends LightningElement {
   selected = 'card selected';
   check = 'corner-check';

  get setSelection() {
    return this.selected === 'card selected' ? 'card selected' : 'card selected';
  }

  get setCheck() {
    return this.check === 'corner-check' ? 'corner-check' : 'corner-check';
  }


  handleClickCalculated() {
    this.selected = 'card selectci';
    this.check = 'corner-checked'
  }
}