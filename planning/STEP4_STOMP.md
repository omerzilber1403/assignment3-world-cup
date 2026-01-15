# Task 4: Implement STOMP Protocol

## Goal
Create complete STOMP protocol implementation with Frame, EncoderDecoder, Protocol, and Server main.

## Files to Create

1. `Frame.java` - STOMP message representation
2. `StompEncoderDecoder.java` - Byte-by-byte parser/builder
3. `StompProtocolImpl.java` - Protocol logic
4. `StompServer.java` - Main entry point

## Part A: Frame.java

### Location
`server/src/main/java/bgu/spl/net/impl/stomp/Frame.java`

### Structure
```java
public class Frame {
    private String command;
    private Map<String, String> headers;
    private String body;
    
    // Constructor, getters, setters
    
    public static Frame parse(String message);
    public String toString();
}
```

### STOMP Frame Format
```
COMMAND
header1:value1
header2:value2

body^@
```
- Empty line separates headers from body
- Body ends with null byte (`\u0000`)

### Commands to Support
- Client → Server: CONNECT, SEND, SUBSCRIBE, UNSUBSCRIBE, DISCONNECT
- Server → Client: CONNECTED, MESSAGE, RECEIPT, ERROR

### Required Frame Examples

#### MESSAGE Frame (Server → Client)
```
MESSAGE
subscription:0
message-id:007
destination:/game/spain_germany

Hello World^@
```

#### RECEIPT Frame (Server → Client)
```
RECEIPT
receipt-id:message-12345

^@
```

#### ERROR Frame (Server → Client)
```
ERROR
message:Not subscribed to channel
receipt-id:77

Detailed error information^@
```

## Part B: StompEncoderDecoder.java

### Location
`server/src/main/java/bgu/spl/net/impl/stomp/StompEncoderDecoder.java`

### State Machine
```java
enum State { COMMAND, HEADERS, BODY }
```

### Implementation
```java
public class StompEncoderDecoder implements MessageEncoderDecoder<Frame> {
    private State currentState = State.COMMAND;
    private StringBuilder buffer = new StringBuilder();
    private String command;
    private Map<String, String> headers = new HashMap<>();
    private StringBuilder bodyBuffer = new StringBuilder();
    
    @Override
    public Frame decodeNextByte(byte nextByte) {
        // State machine logic
        // Return Frame when complete (null terminator found)
        // Return null while accumulating
    }
    
    @Override
    public byte[] encode(Frame message) {
        return message.toString().getBytes();
    }
}
```

### State Transitions
1. **COMMAND:** Read until `\n`, store command, go to HEADERS
2. **HEADERS:** Read until empty line, parse `key:value` pairs, go to BODY
3. **BODY:** Read until `\u0000`, create Frame and reset state

## Part C: StompProtocolImpl.java

### Location
`server/src/main/java/bgu/spl/net/impl/stomp/StompProtocolImpl.java`

### Fields
```java
private int connectionId;
private Connections<Frame> connections;
private String username;
private boolean shouldTerminate;
private Map<Integer, String> subscriptionIdToChannel;
```

### Key Methods

#### start()
```java
public void start(int connectionId, Connections<Frame> connections) {
    this.connectionId = connectionId;
    this.connections = connections;
}
```

#### process()
```java
public void process(Frame frame) {
    // Check if user is logged in (except for CONNECT)
    if (!frame.getCommand().equals("CONNECT") && username == null) {
        sendError("Must connect first", frame.getHeaders().get("receipt"));
        return;
    }
    
    switch (frame.getCommand()) {
        case "CONNECT": handleConnect(frame); break;
        case "SEND": handleSend(frame); break;
        case "SUBSCRIBE": handleSubscribe(frame); break;
        case "UNSUBSCRIBE": handleUnsubscribe(frame); break;
        case "DISCONNECT": handleDisconnect(frame); break;
        default:
            sendError("Unknown command: " + frame.getCommand(), null);
    }
}
```

### Command Handlers (Detailed)

#### handleConnect()
**Requirements:**
- Validate login/passcode headers present
- Check username not already logged in (use Database.login())
- Handle all LoginStatus cases
- Send CONNECTED frame with `version:1.2` header on success
- Send ERROR frame and set shouldTerminate on failure
- Send RECEIPT if receipt header present (after successful login)

**Implementation outline:**
```java
private void handleConnect(Frame frame) {
    String login = frame.getHeaders().get("login");
    String passcode = frame.getHeaders().get("passcode");
    
    if (login == null || passcode == null) {
        sendError("Missing login or passcode header", frame.getHeaders().get("receipt"));
        return;
    }
    
    LoginStatus status = Database.getInstance().login(connectionId, login, passcode);
    
    switch (status) {
        case LOGGED_IN_SUCCESSFULLY:
        case ADDED_NEW_USER:
            this.username = login;
            
            // Send CONNECTED frame
            Map<String, String> headers = new HashMap<>();
            headers.put("version", "1.2");
            Frame connected = new Frame("CONNECTED", headers, "");
            connections.send(connectionId, connected);
            
            // Send RECEIPT if requested
            sendReceipt(frame.getHeaders().get("receipt"));
            break;
            
        case CLIENT_ALREADY_CONNECTED:
            sendError("Client already connected", frame.getHeaders().get("receipt"));
            break;
            
        case ALREADY_LOGGED_IN:
            sendError("User already logged in from another connection", frame.getHeaders().get("receipt"));
            break;
            
        case WRONG_PASSWORD:
            sendError("Wrong password", frame.getHeaders().get("receipt"));
            break;
    }
}
```

#### handleSend()
**CRITICAL Requirements:**
- **Client MUST be subscribed to destination to send** (PDF requirement)
- Get destination from headers
- Validate destination header present
- Check client is subscribed to destination
- Generate unique message-id (using AtomicInteger counter)
- **APPROACH 3:** Create unique MESSAGE frame for EACH subscriber with their subscription-id
- Use `getChannelSubscribers()` to iterate all subscribers
- Send individual MESSAGE frames (NOT via `connections.send(channel, msg)`)
- Send RECEIPT if receipt header present
- Send ERROR and disconnect if not subscribed

**Implementation outline (Approach 3):**
```java
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
    
    // APPROACH 3: Get all subscribers and create unique MESSAGE frame for each
    // Generate unique message ID (same for all copies of this message)
    int messageId = messageIdCounter.incrementAndGet();
    
    // Get all subscribers for this channel
    ConcurrentHashMap<Integer, Integer> subscribers = 
        ((ConnectionsImpl<String>) connections).getChannelSubscribers(destination);
    
    if (subscribers != null && !subscribers.isEmpty()) {
        // Create and send unique MESSAGE frame for each subscriber
        for (Map.Entry<Integer, Integer> entry : subscribers.entrySet()) {
            int subscriberConnectionId = entry.getKey();
            int subscriptionId = entry.getValue();
            
            // Create unique MESSAGE frame with subscriber-specific subscription header
            Frame messageFrame = Frame.createMessage(messageId, destination, subscriptionId, frame.getBody());
            
            // Send directly to this connection (NOT via broadcast)
            connections.send(subscriberConnectionId, messageFrame.toString());
        }
    }
    
    // Send RECEIPT if requested
    sendReceipt(frame.getHeader("receipt"));
}

private boolean isSubscribedTo(String channel) {
    return subscriptionIdToChannel.containsValue(channel);
}
```

#### handleSubscribe()
**Requirements:**
- Get destination and id from headers
- Validate both headers present
- Parse subscription id as integer
- Store subscription mapping (subscriptionId → destination)
- Call `connections.subscribe(connectionId, destination, subscriptionId)`
- Send RECEIPT if receipt header present
- Send ERROR if headers missing or invalid

**Implementation outline:**
```java
private void handleSubscribe(Frame frame) {
    String destination = frame.getHeaders().get("destination");
    String idStr = frame.getHeaders().get("id");
    
    if (destination == null || idStr == null) {
        sendError("Missing destination or id header", frame.getHeaders().get("receipt"));
        return;
    }
    
    try {
        int subscriptionId = Integer.parseInt(idStr);
        
        // Store subscription mapping
        subscriptionIdToChannel.put(subscriptionId, destination);
        
        // Register with connections manager
        connections.subscribe(connectionId, destination, subscriptionId);
        
        // Send RECEIPT if requested
        sendReceipt(frame.getHeaders().get("receipt"));
        
    } catch (NumberFormatException e) {
        sendError("Invalid subscription id: " + idStr, frame.getHeaders().get("receipt"));
    }
}
```

#### handleUnsubscribe()
**Requirements:**
- Get id from headers
- Validate id header present
- Parse subscription id as integer
- Verify subscription exists (check subscriptionIdToChannel)
- Find destination from stored mapping
- Call `connections.unsubscribe(connectionId, subscriptionId)`
- Remove from subscriptionIdToChannel
- Send RECEIPT if receipt header present
- Send ERROR if subscription doesn't exist

**Implementation outline:**
```java
private void handleUnsubscribe(Frame frame) {
    String idStr = frame.getHeaders().get("id");
    
    if (idStr == null) {
        sendError("Missing id header", frame.getHeaders().get("receipt"));
        return;
    }
    
    try {
        int subscriptionId = Integer.parseInt(idStr);
        
        // Verify subscription exists
        if (!subscriptionIdToChannel.containsKey(subscriptionId)) {
            sendError("Invalid subscription id: " + subscriptionId, 
                      frame.getHeaders().get("receipt"));
            return;
        }
        
        // Get destination and remove subscription
        String destination = subscriptionIdToChannel.remove(subscriptionId);
        connections.unsubscribe(connectionId, subscriptionId);
        
        // Send RECEIPT if requested
        sendReceipt(frame.getHeaders().get("receipt"));
        
    } catch (NumberFormatException e) {
        sendError("Invalid subscription id: " + idStr, frame.getHeaders().get("receipt"));
    }
}
```

#### handleDisconnect()
**CRITICAL Requirements:**
- **DISCONNECT frame MUST contain receipt header** (PDF requirement)
- Validate receipt header present
- Send RECEIPT with the receipt-id
- Set shouldTerminate = true
- Send ERROR if receipt header missing

**Implementation outline:**
```java
private void handleDisconnect(Frame frame) {
    String receiptId = frame.getHeaders().get("receipt");
    
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
```

### Helper Methods (CRITICAL)

#### sendReceipt()
**Purpose:** Send RECEIPT frame for any frame that included receipt header

**Implementation:**
```java
private void sendReceipt(String receiptId) {
    if (receiptId != null) {
        Map<String, String> headers = new HashMap<>();
        headers.put("receipt-id", receiptId);
        Frame receipt = new Frame("RECEIPT", headers, "");
        connections.send(connectionId, receipt);
    }
}
```

#### sendError()
**CRITICAL:** ERROR frame MUST close connection after sending (PDF requirement)

**Implementation:**
```java
private void sendError(String errorMessage, String receiptId) {
    Map<String, String> headers = new HashMap<>();
    headers.put("message", errorMessage);
    
    if (receiptId != null) {
        headers.put("receipt-id", receiptId);
    }
    
    Frame error = new Frame("ERROR", headers, errorMessage);
    connections.send(connectionId, error);
    
    // CRITICAL: Must close connection after ERROR
    shouldTerminate = true;
}
```

## Part D: StompServer.java

### Location
`server/src/main/java/bgu/spl/net/impl/stomp/StompServer.java`

### Implementation
```java
public class StompServer {
    public static void main(String[] args) {
        if (args.length < 2) {
            System.err.println("Usage: StompServer <port> <server-type>");
            System.err.println("server-type: tpc | reactor");
            return;
        }
        
        int port = Integer.parseInt(args[0]);
        String serverType = args[1];
        
        Server<Frame> server;
        
        if ("tpc".equals(serverType)) {
            server = Server.threadPerClient(
                port,
                StompProtocolImpl::new,
                StompEncoderDecoder::new
            );
        } else if ("reactor".equals(serverType)) {
            server = Server.reactor(
                Runtime.getRuntime().availableProcessors(),
                port,
                StompProtocolImpl::new,
                StompEncoderDecoder::new
            );
        } else {
            System.err.println("Unknown server type: " + serverType);
            return;
        }
        
        server.serve();
    }
}
```

## Part E: Message ID Generation

### Approach 3 Implementation

**Location:** `server/src/main/java/bgu/spl/net/impl/stomp/StompMessagingProtocolImpl.java`

**Implementation:**
```java
// Static message ID counter shared across all protocol instances
private static final AtomicInteger messageIdCounter = new AtomicInteger(0);

// In handleSend():
int messageId = messageIdCounter.incrementAndGet();
```

**Rationale:**
- No need to modify Database.java (keeps SQL-related logic separate)
- Static field ensures uniqueness across all client connections
- AtomicInteger provides thread-safe incrementing
- Simple and sufficient for STOMP protocol requirements

**Alternative:** Could be added to Database.java if global tracking across server restarts is needed, but not required for assignment.

## Part F: ConnectionsImpl.java Modifications (Approach 3)

### Add Helper Method for Protocol Layer

**Location:** `server/src/main/java/bgu/spl/net/srv/ConnectionsImpl.java`

**Added method:**
```java
/**
 * Get all subscribers for a channel with their subscription IDs.
 * Used by protocol layer to create unique MESSAGE frames per subscriber.
 * 
 * @param channel The channel/destination
 * @return Map of connectionId -> subscriptionId, or null if channel has no subscribers
 */
public ConcurrentHashMap<Integer, Integer> getChannelSubscribers(String channel) {
    return channelSubscriptions.get(channel);
}
```

**Modified send(String channel, T msg):**
```java
@Override
public void send(String channel, T msg) {
    // APPROACH 3: This method should NOT be used for MESSAGE frame broadcasting.
    // MESSAGE frames require unique subscription-id per subscriber.
    // Use getChannelSubscribers() to iterate and create unique frames instead.
    
    // For backward compatibility with potential non-MESSAGE broadcasts:
    ConcurrentHashMap<Integer, Integer> subscribers = channelSubscriptions.get(channel);
    if (subscribers != null) {
        for (Integer connectionId : subscribers.keySet()) {
            send(connectionId, msg);
        }
    }
}
```

**Key Difference from Original Plan:**
- **Original approach:** ConnectionsImpl mutates Frame object to add subscription header (thread-safety issue)
- **Approach 3:** Protocol layer creates unique Frame for each subscriber using `getChannelSubscribers()`
- **Benefit:** Thread-safe, correct subscription headers, clear separation of concerns

## Testing Commands

### Build
```bash
mvn compile
```

### Run TPC Server
```bash
mvn exec:java -Dexec.mainClass="bgu.spl.net.impl.stomp.StompServer" -Dexec.args="7777 tpc"
```

### Run Reactor Server
```bash
mvn exec:java -Dexec.mainClass="bgu.spl.net.impl.stomp.StompServer" -Dexec.args="7777 reactor"
```

## Implementation Order

1. **Frame.java** (parse and toString) ✅
2. **StompEncoderDecoder.java** (state machine) ✅
3. **ConnectionsImpl.java modifications** (add getChannelSubscribers) ✅
4. **StompMessagingProtocolImpl.java** (Approach 3: command handlers with per-subscriber MESSAGE frames) ✅
5. **StompServer.java** (main method)

**Note:** Database.java modifications NOT required - message ID generation handled in StompMessagingProtocolImpl.

## Critical Requirements Checklist

### MESSAGE Frame Requirements ✅
- [ ] `subscription` header added by ConnectionsImpl when delivering
- [ ] `message-id` header with server-unique ID
- [ ] `destination` header copied from SEND
- [ ] Body copied from original SEND frame

### SEND Frame Validation ✅
- [ ] Check client is subscribed to destination
- [ ] Send ERROR if not subscribed
- [ ] Close connection after ERROR

### ERROR Frame Behavior ✅
- [ ] Always set shouldTerminate = true after sending ERROR
- [ ] Include `message` header with error description
- [ ] Include `receipt-id` header if original frame had receipt

### RECEIPT Frame ✅
- [ ] Can be requested on ANY client frame (CONNECT, SEND, SUBSCRIBE, UNSUBSCRIBE, DISCONNECT)
- [ ] Uses `receipt-id` header (not `receipt`)
- [ ] Value matches original `receipt` header value

### DISCONNECT Requirements ✅
- [ ] MUST include receipt header
- [ ] Send ERROR if receipt missing
- [ ] Send RECEIPT before setting shouldTerminate

### Login Validation ✅
- [ ] All commands except CONNECT require user to be logged in
- [ ] Send ERROR if not logged in
- [ ] Use Database.login() for authentication
- [ ] Handle all LoginStatus cases

### Thread Safety ✅
- [ ] Message ID counter is AtomicInteger
- [ ] ConnectionsImpl uses ConcurrentHashMap
- [ ] All shared state properly synchronized

## PDF Compliance Notes

1. **Section 2.5.1 - Server Frames:**
   - MESSAGE frame: subscription + message-id + destination headers ✅
   - RECEIPT frame: receipt-id header with matching value ✅
   - ERROR frame: must close connection after sending ✅

2. **Section 2.5.2 - Client Frames:**
   - SEND: client must be subscribed to destination ✅
   - SUBSCRIBE: id header used for subscription tracking ✅
   - UNSUBSCRIBE: id must match existing subscription ✅
   - DISCONNECT: must include receipt header ✅

3. **Receipt Header:**
   - Can be added to ANY client frame ✅
   - Server must respond with RECEIPT frame ✅
   - receipt-id in response matches receipt in request ✅

## Next Step
→ After completing this task, server is fully functional and PDF-compliant. Test with client.
