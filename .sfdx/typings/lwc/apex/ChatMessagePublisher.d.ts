declare module "@salesforce/apex/ChatMessagePublisher.publishEvent" {
  export default function publishEvent(param: {message: any, userName: any, receiverName: any}): Promise<any>;
}
