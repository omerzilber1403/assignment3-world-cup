package bgu.spl.net.srv;

import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;

public class ConnectionsImpl<T> implements Connections<T> {

    private final ConcurrentHashMap<Integer, ConnectionHandler<T>> handlers;
    private final ConcurrentHashMap<String, ConcurrentHashMap<Integer, String>> channelSubscriptions;
    private final ConcurrentHashMap<Integer, ConcurrentHashMap<String, String>> clientSubscriptions;

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
        // MESSAGE frames require unique subscription-id per subscriber.
        // Use getChannelSubscribers() to iterate and create unique frames instead.
        // The implementation for this function will be in the protocol handler
    }
    
    /**
     * Get all subscribers for a channel with their subscription IDs.
     * Used by protocol layer to create unique MESSAGE frames per subscriber.
     * 
     * @param channel The channel/destination
     * @return Map of connectionId -> subscriptionId, or null if channel has no subscribers
     */
    public ConcurrentHashMap<Integer, String> getChannelSubscribers(String channel) {
        return channelSubscriptions.get(channel);
    }

    @Override
    public void disconnect(int connectionId) {
        ConnectionHandler<T> handler = handlers.remove(connectionId);
        if (handler != null) {
            ConcurrentHashMap<String, String> subscriptions = clientSubscriptions.remove(connectionId);
            if (subscriptions != null) {
                for (String channel : subscriptions.keySet()) {
                    ConcurrentHashMap<Integer, String> channelSubs = channelSubscriptions.get(channel);
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

    public void subscribe(int connectionId, String channel, String subscriptionId) {
        channelSubscriptions.computeIfAbsent(channel, k -> new ConcurrentHashMap<>())
                .put(connectionId, subscriptionId);
        
        ConcurrentHashMap<String, String> clientSubs = clientSubscriptions.get(connectionId);
        if (clientSubs != null) {
            clientSubs.put(channel, subscriptionId);
        }
    }

    public void unsubscribe(int connectionId, String subscriptionId) {
        ConcurrentHashMap<String, String> clientSubs = clientSubscriptions.get(connectionId);
        if (clientSubs != null) {
            String channelToRemove = null;
            for (ConcurrentHashMap.Entry<String, String> entry : clientSubs.entrySet()) {
                if (entry.getValue().equals(subscriptionId)) {
                    channelToRemove = entry.getKey();
                    break;
                }
            }
            
            if (channelToRemove != null) {
                clientSubs.remove(channelToRemove);
                
                ConcurrentHashMap<Integer, String> channelSubs = channelSubscriptions.get(channelToRemove);
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
