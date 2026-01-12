package bgu.spl.net.impl.stomp;

public class Subscription {
    private final String topic;
    private final int connectionId;
    private final String subscriptionId;

    public Subscription(String topic, int connectionId, String subscriptionId){
        this.topic = topic;
        this.connectionId = connectionId;
        this.subscriptionId = subscriptionId;
    }

    public String getTopic(){
        return topic;
    }
    public int getConnectionId(){
        return connectionId;
    }
    public String getSubscriptionId(){
        return subscriptionId;
    }
    

}

