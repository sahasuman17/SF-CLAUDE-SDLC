import { LightningElement,api,wire,track } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';
import NOTIFICATION_SOUND from '@salesforce/resourceUrl/notification_sound';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import publishEvent from '@salesforce/apex/ChatMessagePublisher.publishEvent';


export default class LiveChat extends LightningElement {

@api userId = USER_ID;
    @api timeString;
    @api error;
    @track chat_response;
    @track isTyping = false;
    @api toName;
    @track apiResponse;
    @track guid;
    @track citations='';
    @track messages = [];
    @track receiverName;
    subscription = {};
    @api channelName = '/event/ChatMessageEvent__e';
    inputPlaceholderText = 'Type your message and press enter';
    result;
    showChatWindow=true;
    is_escalated = false;
    noficationAudio=NOTIFICATION_SOUND;
    toUserOrGroupId=123;
    @track senderName = '';
    masterData;
    @api showSpinner=false;

    userName;

    @wire(getRecord, {
        recordId: USER_ID,
        fields: [NAME_FIELD]
    })
    user({ error, data }) {
        if (data) {
            this.userName = data.fields.Name.value;
        } else if (error) {
            console.error(error);
        }
    }

    connectedCallback(){
        this.handleSubscribe();
        onError(error => {
            console.error('EMP API error: ', error);
        });       
    }

    handleSendMessage(msg) {
        try{
            console.log('msg***',msg+'^^^'+this.senderName);
        publishEvent({ message: msg,userName:this.senderName,receiverName :this.receiverName})
            .then(() => {
                console.log('published...');
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
        }catch (error){
            console.error('Error in API call:', error.message);
        }
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            console.log('New message received 1: ', response);
            console.log('New message received 2: ', response);
            let obj = JSON.parse(JSON.stringify(response));
            console.log('property data',obj.data.payload.Message__c);
            this.message = this.formattedResponse(obj.data.payload.Message__c);
            this.senderName = obj.data.payload.userName__c;
            this.receiverName = obj.data.payload.receiverName__c;
            console.log('***',this.senderName+'---'+this.receiverName);
            if(this.message!=undefined && this.userName == this.receiverName){
                this.appendResponse();
                this.scrollToBottom(0);
            }
        };

        subscribe(this.channelName, -1, messageCallback).then(response => {
            console.log('Subscription request sent to: ', JSON.stringify(response.channel));
            this.subscription = response;
        });

    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }
    
    handleUnsubscribe() {
        unsubscribe(this.subscription, response => {
            console.log('Unsubscribed from channel: ', JSON.stringify(response));
        });
    }
    renderedCallback() {
        //this.appendResponse();
    }

    scrollToBottom(height) {
        const container = this.template.querySelector('.chatroom__messages');
        container.scrollTop = container.scrollHeight+height;
    }

    handleSpinner()
    {
        this.showSpinner=false;
    }

    beep(){
        var playSound = new Audio(this.noficationAudio);
        playSound.load();
        playSound.play()
    }
    handleKeyDown(event) {
        if (event.key === 'Enter') {
            const message = event.target.value.trim();
            if (message) {
                const currentTime = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); 
                this.receiverName = (this.senderName!=this.userName)? 
                                    this.senderName:this.receiverName;
                this.senderName = this.userName;
                console.log('^^^^',this.senderName+'---'+this.receiverName);                             
                this.handleSendMessage(message);                    
                this.appendRequest(message, this.userName, currentTime);
                
                //this.isTyping = true;
                this.scrollToBottom(0);
                event.target.value = ''; // Clear the input box
            }
        }
    }

    appendResponse() {
        // Create the li element
        const liElement = document.createElement('li');
        const currentTime = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        liElement.className = 'slds-chat-listitem slds-chat-listitem_outbound';
        this.beep();
        // Create the div elements and span with text
        liElement.innerHTML = `
            <div class="slds-chat-message">
                <div class="slds-chat-message__body">
                <div class="slds-chat-message__meta" aria-label="said ${this.senderName} at ${currentTime}">${this.senderName} • ${currentTime}</div>
                    <div style="padding-top:6px !important;background:#ecf5fe;color:black;padding-bottom-3px !important" class="slds-chat-message__text_outbound">
                        <span>
                        ${this.message}
                        </span>
                    </div>
                  
                </div>
            </div>
        `;
        // Append the li element to the ul with class slds-chat-list
        this.template.querySelector('ul.chat-request').appendChild(liElement);
        this.isTyping = false;
    }

    appendRequest(message, userName, currentTime) {
        // Create the li element
        const liElement = document.createElement('li');
        liElement.className = 'slds-chat-listitem slds-chat-listitem_inbound';

        // Create the div elements and span with text
        liElement.innerHTML = `
            <div class="slds-chat-message">
                <div class="slds-chat-message__body">
                <div class="slds-chat-message__meta" aria-label="said ${userName} at ${currentTime}">${userName} • ${currentTime}</div>
                    <div style="padding-top:6px !important;padding-bottom-3px !important" class="slds-chat-message__text_inbound">
                        <span>
                        ${message}
                        </span>
                    </div>
                </div>
            </div>
        `;

        // Append the li element to the ul with class slds-chat-list
        this.template.querySelector('ul.chat-request').appendChild(liElement);
        //this.scrollToBottom(300);
    }


    formattedResponse(summary) {
        let formattedSummary = summary
            .replace(/•/g,"</br>•")
            .replace(/\n\n/g,"</br></br>")
            .replace(/\n/g,"</br>")
        return formattedSummary;
    }
    


}