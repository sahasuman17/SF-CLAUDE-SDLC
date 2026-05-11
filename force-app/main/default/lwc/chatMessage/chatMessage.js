import { LightningElement,api,wire,track } from 'lwc';
import NOTIFICATION_SOUND from '@salesforce/resourceUrl/notification_sound';
export default class ChatMessage extends LightningElement {
    @track message='';
     timeString;
    @api userId;
    @api toUserOrGroupId;
    inputPlaceholderText='Type your message and press enter';
    noficationAudio=NOTIFICATION_SOUND;
    @api toName ='Anmol';
    @api toIcon;
}