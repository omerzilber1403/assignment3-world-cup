package bgu.spl.net.srv;

import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;

public class ConnectionsImpl<T> implements Connections<T> {

    private final ConcurrentHashMap<Integer, ConnectionHandler<T>> handlers;
    private final ConcurrentHashMap<String, ConcurrentHashMap<Integer, Integer>> channelSubscriptions;
    private final ConcurrentHashMap<Integer, ConcurrentHashMap<String, Integer>> clientSubscriptions;

    public ConnectionsImpl() {
        this.handlers = new ConcurrentHashMap<>();
        this.channelSubscriptions = new ConcurrentHashMap<>();
        this.clientSubscriptions = new ConcurrentHashMap<>();
    }

    public void connect(int connectionId, ConnectionHandler<T> handler) {
        handlers.put(connectionId, handler);
        clientSubscriptions.put(connectionId, new ConcurrentHashMap<>());
    }

    @Override
    public boolean send(int connectionId, T msg) {
        ConnectionHandler<T> handler = handlers.get(connectionId);
        if (handler != null) {
            handler.send(msg);
            return true;
        }
        return false;
    }

    @Override
    public void send(String channel, T msg) {
        ConcurrentHashMap<Integer, Integer> subscribers = channelSubscriptions.get(channel);
        if (subscribers != null) {
            for (Integer connectionId : subscribers.keySet()) {
                send(connectionId, msg);
            }
        }
    }

    @Override
    public void disconnect(int connectionId) {
        ConnectionHandler<T> handler = handlers.remove(connectionId);
        if (handler != null) {
            ConcurrentHashMap<String, Integer> subscriptions = clientSubscriptions.remove(connectionId);
            if (subscriptions != null) {
                for (String channel : subscriptions.keySet()) {
                    ConcurrentHashMap<Integer, Integer> channelSubs = channelSubscriptions.get(channel);
                    if (channelSubs != null) {
                        channelSubs.remove(connectionId);
                        if (channelSubs.isEmpty()) {
                            channelSubscriptions.remove(channel);
                        }
                    }
                }
            }
            try {
                handler.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    public void subscribe(int connectionId, String channel, int subscriptionId) {
        channelSubscriptions.computeIfAbsent(channel, k -> new ConcurrentHashMap<>())
                .put(connectionId, subscriptionId);
        
        ConcurrentHashMap<String, Integer> clientSubs = clientSubscriptions.get(connectionId);
        if (clientSubs != null) {
            clientSubs.put(channel, subscriptionId);
        }
    }

    public void unsubscribe(int connectionId, int subscriptionId) {
        ConcurrentHashMap<String, Integer> clientSubs = clientSubscriptions.get(connectionId);
        if (clientSubs != null) {
            String channelToRemove = null;
            for (ConcurrentHashMap.Entry<String, Integer> entry : clientSubs.entrySet()) {
                if (entry.getValue() == subscriptionId) {
                    channelToRemove = entry.getKey();
                    break;
                }
            }
            
            if (channelToRemove != null) {
                clientSubs.remove(channelToRemove);
                
                ConcurrentHashMap<Integer, Integer> channelSubs = channelSubscriptions.get(channelToRemove);
                if (channelSubs != null) {
                    channelSubs.remove(connectionId);
                    if (channelSubs.isEmpty()) {
                        channelSubscriptions.remove(channelToRemove);
                    }
                }
            }
        }
    }
}
