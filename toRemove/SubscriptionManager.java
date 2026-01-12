package bgu.spl.net.impl.stomp;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicInteger;

import bgu.spl.net.srv.Connections;

public class SubscriptionManager {
    
private static final SubscriptionManager INSTANCE = new SubscriptionManager();
private SubscriptionManager(){
    //make the default constructor private
}

public static SubscriptionManager getInstance(){
    return INSTANCE;
}
//map channel -> subscribers
private final ConcurrentHashMap<String, ConcurrentLinkedQueue<Subscription>> channelMap = new ConcurrentHashMap<>();
//map client -> channels
private final ConcurrentHashMap<Integer, ConcurrentLinkedQueue<Subscription>> clientMap = new ConcurrentHashMap<>();
private final AtomicInteger globalMessageCounter = new AtomicInteger(0);


public void subscribe(String topic, int connectionId, String subscriptionId){
    Subscription newSub = new Subscription(topic, connectionId, subscriptionId);
    if(channelMap.get(topic) != null){
        channelMap.get(topic).add(newSub);
    } else {
        ConcurrentLinkedQueue<Subscription> newQueue = new ConcurrentLinkedQueue<>();
        newQueue.add(newSub);
        channelMap.put(topic, newQueue); 
    }
    
    if(clientMap.get(connectionId) != null){
        clientMap.get(connectionId).add(newSub);
    } else {
         ConcurrentLinkedQueue<Subscription> newQueue = new ConcurrentLinkedQueue<>();
        newQueue.add(newSub);
        clientMap.put(connectionId, newQueue); 
    }
}

public void unsubscribe(String subscriptionId, int connectionId){
    ConcurrentLinkedQueue<Subscription> clientSubscriptions = clientMap.get(connectionId);
    if(clientSubscriptions != null){
        Subscription subscriptionToRemove = null;
        for(Subscription sub : clientMap.get(connectionId)){
            if(sub.getSubscriptionId().equals(subscriptionId)){
                subscriptionToRemove = sub;
            }
        }
        if(subscriptionToRemove != null){
            channelMap.get(subscriptionToRemove.getTopic()).remove(subscriptionToRemove);
            clientMap.get(connectionId).remove(subscriptionToRemove);
        }
    }
}

public void broadcast(String topic, String message, Connections<String> connections){
    ConcurrentLinkedQueue<Subscription> subscriptions = channelMap.get(topic);
    if(subscriptions != null){
        for(Subscription sub : subscriptions){
            String returnMessage = "MESSAGE\n" + 
                                   "subscription:" + sub.getSubscriptionId() + "\n" +
                                   "message-id:" + globalMessageCounter.incrementAndGet() + "\n" +
                                   "destination:" + sub.getTopic() + "\n\n" +
                                   message + "\u0000";
            connections.send(sub.getConnectionId(), returnMessage);
        }
    }
}

public void clearConnection(int connectionId){
    //get userChannels and remove the queue
    ConcurrentLinkedQueue<Subscription> userSubscriptions = clientMap.remove(connectionId);
    if(userSubscriptions != null){
        for(Subscription sub : userSubscriptions){   
        ConcurrentLinkedQueue<Subscription> channelSubscriptionsQueue = channelMap.get(sub.getTopic());
        if(channelSubscriptionsQueue != null){
            channelSubscriptionsQueue.remove(sub);
        }
    }
 
}

}










}
