import { LightningElement,api,wire,track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { loadStyle } from 'lightning/platformResourceLoader';
import styles from '@salesforce/resourceUrl/globalCss';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';
import NOTIFICATION_SOUND from '@salesforce/resourceUrl/notification_sound';
import publishEvent from '@salesforce/apex/ChatMessagePublisher.publishEvent';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'

export default class ChatBot extends LightningElement {

@api userId = USER_ID;
    @api timeString;
    @api error;
    @track chat_response;
    @track isTyping = false;
    @api toName;
    @track apiResponse;
    @track guid;
    @track citations='';
    @track hasSource = 'none';
    @track receiverName = 'Brian Johnson';
    inputPlaceholderText='Type your message and press enter';
    result;
    showChatWindow=true;
    initialText = '';
    is_escalated = false;
    noficationAudio=NOTIFICATION_SOUND;
    toUserOrGroupId=123;
    messages;
    @track botName = 'Agent Bot';
    masterData;
    @api showSpinner=false;

    userName;
    _recognition;
    //textToRead = IMAGES;
    isVoiceInput = false;
    searchKey = '';
    isNotListening = true;

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
        //this.template.addEventListener('oncustomclick', this.handleCustomClick.bind(this)); 
        this.guid = this.uuidv4();

        /*window.SpeechRecognition = window.webkitSpeechRecognition || window.SpeechRecognition;
        // console.log('@@window:' + JSON.stringify(window));
        if ("SpeechRecognition" in window) {
            console.log('Inside Connected callback');
            this._recognition = new webkitSpeechRecognition() || new SpeechRecognition();
            this._recognition.lang = 'en-US';
            this._recognition.continuous = true;
        }
        */
        // loading static resource
        loadStyle(this, styles + '/globalCss/globalStyle.css')
        .then(() => console.log('GlobalStyles loaded.'))
        .catch(error => console.log("Error " + error.message))
    }

     wait(time) {
        return new Promise(resolve => {
            setTimeout(resolve, time);
        });
    }
    async doAction(event) {
        console.log('&&doAction');
       
        
        window.SpeechRecognition = window.webkitSpeechRecognition || window.SpeechRecognition;
        // console.log('@@window:' + JSON.stringify(window));
        if ("SpeechRecognition" in window) {
            console.log('Inside Connected callback');
            this._recognition = new webkitSpeechRecognition() || new SpeechRecognition();
            this._recognition.lang = 'en-US';
            this._recognition.continuous = true;
        }
        
        if (!this.isNotListening) {
            this._recognition.abort();
            console.log("Speech recognition has stopped.");
            this.isNotListening = true;
        }
        else {
            this.isVoiceInput = true;
            this.isNotListening = false;
            // this.isLoading = true;
            // this.searchKey = 'Listening........';`
            this.searchKey = '';
            console.log('&&beforeWaiting');
            
            this._recognition.start();
            this.initialText = 'Waiting...........';
            await this.wait(5000);
            console.log('&&Waiting');
            this.initialText = 'Listening...........';
            //When a result has been successfully recognized, the result event fires
            this._recognition.onresult = (event) => {
                console.log('&&event' + JSON.stringify(event.results[0][0]));
                var msg = event.results[0][0].transcript;
                console.log('&&msg' + msg);
                this.handleSpeechRecognized(msg);
            }
        }
    }
    //Extract the text results and add it to the Chatter.
    handleSpeechRecognized(msg) {

        console.log('&&handleSpeechRecognized' + msg);
        this.searchKey = msg;        
        // this.isLoading = false;
        this.isNotListening = true;

    }

    handleSendMessage(msg) {
        try{
            console.log('msg***',msg);
        publishEvent({ message: msg,userName:this.userName,receiverName :this.receiverName })
            .then(() => {
                this.showToast('Success', 'Message routed to the agent', 'success');
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
        }catch (error){
            console.error('Error in API call:', error.message);
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
        });
        this.dispatchEvent(event);
    }


    handleChat(event)
    {
        this.showSpinner=true;
        this.toUserOrGroupId=event.target.dataset.id;
        this.toName=event.target.dataset.name;
        this.toIcon=event.target.dataset.icon;
        console.log('userOrGroupId',this.toUserOrGroupId);
        this.showChatWindow=true;
        this.showSpinner=false;
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
        autoSubmitTextForSearch(msg){
        const message = msg;//event.target.value.trim();
            console.log('&&message' + message);
            if (message) {
                const currentTime = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                console.log('&&currentTime' + currentTime);

                this.appendRequest(message, this.userName, currentTime);
                this.isTyping = true;
                this.scrollToBottom(0);
                this.handleApiCall(message);
                //event.target.value = ''; // Clear the input box
                //this.searchKey = '';
            }
    }
    handleKeyDown(event) {
        console.log('&&handleKeyDown' + event.key);
        if (event.key === 'Enter') {
            const message = event.target.value.trim();
            console.log('&&message' + message);
            this.autoSubmitTextForSearch(message);
            event.target.value = ''; // Clear the input box
            this.searchKey = '';
            /*
            const message = msg;//event.target.value.trim();
            console.log('&&message' + message);
            if (message) {
                const currentTime = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                console.log('&&currentTime' + currentTime);

                this.appendRequest(message, this.userName, currentTime);
                this.isTyping = true;
                this.scrollToBottom(0);
                this.handleApiCall(message);
                //event.target.value = ''; // Clear the input box
                //this.searchKey = '';
                */
            }
        }

    doStop(){
        window.speechSynthesis.cancel();
    }
            
    doReadText(){
        console.log('&&Read Text');
         var textValue = this.chat_response;
         console.log('&&textValue' + textValue);
         this.utterance = new SpeechSynthesisUtterance(textValue);
         window.speechSynthesis.speak(this.utterance);
         this.utterance.onstart = function (event) {
            console.log('The utterance started to be spoken.')
         };
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
                <div class="slds-chat-message__meta" aria-label="said ${this.botName} at ${currentTime}">${this.botName} • ${currentTime}</div>
                    <div style="padding-top:6px !important;background:#ecf5fe;color:black;padding-bottom-3px !important" class="slds-chat-message__text_outbound">
                        <span>
                        ${this.chat_response}
                        </span>
                    <br/>
                    <br/>
                    <div style="display:${this.hasSource}" >
                        <b>Sources:</b> ${this.citations}                    
                    </div>
                    </div>
                  
                </div>
            </div>
        `;
        // Append the li element to the ul with class slds-chat-list
        this.template.querySelector('ul.chat-request').appendChild(liElement);
        
        if(this.isVoiceInput){
            this.doReadText();
            this.isVoiceInput = false;
       }
        this.isTyping = false;
    }

uuidv4() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    .replace(/[xy]/g, function (c) {
        const r = Math.random() * 16 | 0, 
            v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
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

    async handleApiCall(message) {
        const endpoint = 'https://xws9bm504j.execute-api.us-east-1.amazonaws.com/stg/chat';
        const requestBody = {
        session_id: this.guid,
        eval_required: false,
        user_query: `${message}`
      };

        try {console.log('Request**'+JSON.stringify(requestBody));
            console.log('GUID=='+this.guid);
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-api-key': 'HTCHL77uXq2c9Fr99TgG211Cu6OL5FsLslnseNUj',
                    // Add other necessary headers here
                },
                body: JSON.stringify(requestBody)
            });

            if (response.ok) {
              console.log('log1**')
              this.citations = '';
              this.hasSource = 'none';
                const data = await response.json();
                this.apiResponse = data;
                this.apiResponse["citations"].forEach(cit => {
                    if(this.apiResponse["citations"].length ==1){
                        this.citations+= "<a style=display:block;color:black; href="+cit+" value ="+cit+">"+cit+"</a>"; 
                        this.hasSource = 'block';
                    }else{
                        this.citations+= "<a style=display:block;color:black; href="+cit+" value ="+cit+">"+cit+"</a><br/>"; 
                        this.hasSource = 'block';
                        
                    }
                    
                });
                
                if(this.apiResponse != undefined){
                    console.log('API Response:', this.apiResponse["chat_response"]);
                    this.chat_response = this.formattedResponse(this.apiResponse["chat_response"]);
                    
                   this.is_escalated = this.apiResponse["is_escalated"];
                   console.log('IsEscalated=',this.is_escalated);
                   if(this.is_escalated === true){
                        this.guid = this.uuidv4();
                        this.handleSendMessage(this.apiResponse["chat_summary"]);
                        this.is_escalated = false;
                        
                   }else{
                        console.log('cit***',this.citations);
                   }
                   this.appendResponse();
                   this.scrollToBottom(0);
                }
            } else {
                this.isTyping = true;
                this.handleApiCall(message);
                //throw new Error('Network response was not ok.');
            }
        } catch (error) {
            console.error('Error in API call:', error.message);
            this.isTyping = false;
        }
    }

    formattedResponse(summary) {
        let formattedSummary = summary
            .replace(/•/g,"</br>•")
            .replace(/\n\n/g,"</br></br>")
            .replace(/\n/g,"</br>")
        return formattedSummary;
    }
    


}