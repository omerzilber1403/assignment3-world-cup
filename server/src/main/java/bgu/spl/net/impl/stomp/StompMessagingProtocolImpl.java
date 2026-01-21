package bgu.spl.net.impl.stomp;

import bgu.spl.net.api.StompMessagingProtocol;
import bgu.spl.net.impl.data.Database;
import bgu.spl.net.impl.data.LoginStatus;
import bgu.spl.net.srv.Connections;
import bgu.spl.net.srv.ConnectionsImpl;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

public class StompMessagingProtocolImpl implements StompMessagingProtocol<String> {
    
    private int connectionId;
    private Connections<String> connections;
    private String username;
    private boolean shouldTerminate;
    private Map<String, String> subscriptionIdToChannel;
    
    // Static message ID counter shared across all protocol instances
    private static final AtomicInteger messageIdCounter = new AtomicInteger(0);
    
    public StompMessagingProtocolImpl() {
        this.username = null;
        this.shouldTerminate = false;
        this.subscriptionIdToChannel = new HashMap<>();
    }
    
    @Override
    public void start(int connectionId, Connections<String> connections) {
        this.connectionId = connectionId;
        this.connections = connections;
    }
    
    @Override
    public void process(String message) {
        Frame frame = Frame.parse(message);
        
        if (frame == null) {
            sendError("Invalid frame format", null);
            return;
        }
        
        // Check if user is logged in (except for CONNECT)
        if (!frame.getCommand().equals("CONNECT") && username == null) {
            sendError("Must connect first", frame.getHeader("receipt"));
            return;
        }
        
        switch (frame.getCommand()) {
            case "CONNECT":
                handleConnect(frame);
                break;
            case "SEND":
                handleSend(frame);
                break;
            case "SUBSCRIBE":
                handleSubscribe(frame);
                break;
            case "UNSUBSCRIBE":
                handleUnsubscribe(frame);
                break;
            case "DISCONNECT":
                handleDisconnect(frame);
                break;
            default:
                sendError("Unknown command: " + frame.getCommand(), null);
        }
    }
    
    @Override
    public boolean shouldTerminate() {
        return shouldTerminate;
    }
    
    // ==================== COMMAND HANDLERS ====================
    
    private void handleConnect(Frame frame) {
        String login = frame.getHeader("login");
        String passcode = frame.getHeader("passcode");
        
        if (login == null || passcode == null) {
            sendError("Missing login or passcode header", frame.getHeader("receipt"));
            return;
        }
        
        LoginStatus status = Database.getInstance().login(connectionId, login, passcode);
        
        switch (status) {
            case LOGGED_IN_SUCCESSFULLY:
            case ADDED_NEW_USER:
                this.username = login;
                
                // Send CONNECTED frame
                Frame connected = Frame.createConnected();
                connections.send(connectionId, connected.toString());
                
                // Send RECEIPT if requested
                sendReceipt(frame.getHeader("receipt"));
                break;
                
            case CLIENT_ALREADY_CONNECTED:
                sendError("Client already connected", frame.getHeader("receipt"));
                break;
                
            case ALREADY_LOGGED_IN:
                sendError("User already logged in from another connection", frame.getHeader("receipt"));
                break;
                
            case WRONG_PASSWORD:
                sendError("Wrong password", frame.getHeader("receipt"));
                break;
        }
    }
    
    private void handleSend(Frame frame) {
        String destination = frame.getHeader("destination");
        
        if (destination == null) {
            sendError("Missing destination header", frame.getHeader("receipt"));
            return;
        }
        
        // CRITICAL: Check if client is subscribed to destination
        if (!isSubscribedTo(destination)) {
            sendError("Cannot send to channel not subscribed to: " + destination, 
                      frame.getHeader("receipt"));
            return;
        }
        
        // Track file upload in database (Section 3.3)
        // Extract game channel from destination (format: "/game_channel")
        String gameChannel = destination.startsWith("/") ? destination.substring(1) : destination;
        
        // Parse body to check if this is a game event report
        String body = frame.getBody();
        if (body != null && body.contains("user:") && body.contains("event name:")) {
            // This is a game event - track it as file upload
            // Extract filename from context or use generic name
            String filename = "game_events.json"; // Generic name
            Database.getInstance().trackFileUpload(username, filename, gameChannel);
        }
        
        // APPROACH 3: Get all subscribers and create unique MESSAGE frame for each
        // Generate unique message ID (same for all copies of this message)
        int messageId = messageIdCounter.incrementAndGet();
        
        // Get all subscribers for this channel
        ConcurrentHashMap<Integer, String> subscribers = null;
        if (connections instanceof ConnectionsImpl) {
            subscribers = ((ConnectionsImpl<String>) connections).getChannelSubscribers(destination);
        }
        
        if (subscribers != null && !subscribers.isEmpty()) {
            // Create and send unique MESSAGE frame for each subscriber
            for (Map.Entry<Integer, String> entry : subscribers.entrySet()) {
                int subscriberConnectionId = entry.getKey();
                String subscriptionId = entry.getValue();
                
                // Create unique MESSAGE frame with subscriber-specific subscription header
                Frame messageFrame = Frame.createMessage(messageId, destination, subscriptionId, frame.getBody());
                
                // Send directly to this connection (NOT via broadcast)
                connections.send(subscriberConnectionId, messageFrame.toString());
            }
        }
        
        // Send RECEIPT if requested
        sendReceipt(frame.getHeader("receipt"));
    }
    
    private void handleSubscribe(Frame frame) {
        String destination = frame.getHeader("destination");
        String subscriptionId = frame.getHeader("id");
        
        if (destination == null || subscriptionId == null) {
            sendError("Missing destination or id header", frame.getHeader("receipt"));
            return;
        }
        
        // Store subscription mapping
        subscriptionIdToChannel.put(subscriptionId, destination);
        
        // Register with connections manager
        connections.subscribe(connectionId, destination, subscriptionId);
        
        // Send RECEIPT if requested
        sendReceipt(frame.getHeader("receipt"));
    }
    
    private void handleUnsubscribe(Frame frame) {
        String subscriptionId = frame.getHeader("id");
        
        if (subscriptionId == null) {
            sendError("Missing id header", frame.getHeader("receipt"));
            return;
        }
        
        // Verify subscription exists
        if (!subscriptionIdToChannel.containsKey(subscriptionId)) {
            sendError("Invalid subscription id: " + subscriptionId, 
                      frame.getHeader("receipt"));
            return;
        }
        
        // Remove subscription
        subscriptionIdToChannel.remove(subscriptionId);
        connections.unsubscribe(connectionId, subscriptionId);
        
        // Send RECEIPT if requested
        sendReceipt(frame.getHeader("receipt"));
    }
    
    private void handleDisconnect(Frame frame) {
        String receiptId = frame.getHeader("receipt");
        
        // DISCONNECT MUST have receipt header
        if (receiptId == null) {
            sendError("DISCONNECT must include receipt header", null);
            return;
        }
        
        // Send receipt acknowledgment
        sendReceipt(receiptId);
        
        // Mark for disconnection
        shouldTerminate = true;
    }
    
    // ==================== HELPER METHODS ====================
    
    private boolean isSubscribedTo(String channel) {
        return subscriptionIdToChannel.containsValue(channel);
    }
    
    private void sendReceipt(String receiptId) {
        if (receiptId != null) {
            Frame receipt = Frame.createReceipt(receiptId);
            connections.send(connectionId, receipt.toString());
        }
    }
    
    private void sendError(String errorMessage, String receiptId) {
        Frame error = Frame.createError(errorMessage, receiptId, errorMessage);
        connections.send(connectionId, error.toString());
        
        // CRITICAL: Must close connection after ERROR
        shouldTerminate = true;
    }
}
