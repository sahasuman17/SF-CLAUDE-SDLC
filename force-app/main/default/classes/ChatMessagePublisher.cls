public without sharing class ChatMessagePublisher {
    @AuraEnabled
    public static void publishEvent(String message,String userName, String receiverName) {
        //system.assertEquals('expected', 'actual');
        ChatMessageEvent__e event = new ChatMessageEvent__e(Message__c = message, userName__c = userName,
                                                            receiverName__c = receiverName);
        Database.SaveResult sr = EventBus.publish(event);

        if (!sr.isSuccess()) {
            for (Database.Error error : sr.getErrors()) {
                System.debug('Error returned: ' +
                             error.getStatusCode() +
                             ' - ' +
                             error.getMessage());
            }
        }
    }
}