# Approach 3: Per-Subscriber MESSAGE Frame Broadcasting

## Overview

This document describes the **Approach 3** implementation for STOMP MESSAGE frame broadcasting, where each subscriber receives a unique MESSAGE frame with their specific subscription-id header.

## Problem Statement

The STOMP protocol requires that each MESSAGE frame sent to a subscriber includes a `subscription` header with the subscriber's unique subscription-id. When multiple clients subscribe to the same channel with different subscription-ids, broadcasting a single MESSAGE frame to all subscribers would result in all subscribers receiving the same subscription-id value, which violates the protocol specification.

### Example Scenario

```
Channel: /topic/sports
  - Client A subscribed with subscription-id: 5
  - Client B subscribed with subscription-id: 12
  - Client C subscribed with subscription-id: 8

When a message is sent to /topic/sports:
  - Client A must receive: MESSAGE with subscription:5
  - Client B must receive: MESSAGE with subscription:12
  - Client C must receive: MESSAGE with subscription:8
```

## Three Possible Approaches

### ❌ Approach 1: Mutate Shared Frame Object (Thread-Unsafe)

**Original plan from STEP4_STOMP.md:**
- Protocol creates ONE MESSAGE frame
- Calls `connections.send(channel, frame)`
- ConnectionsImpl iterates subscribers and mutates the Frame object's headers for each

**Problems:**
- **Thread safety issue:** Multiple threads could mutate the same Frame simultaneously
- **Incorrect subscription headers:** Last mutation wins, all subscribers see the same value
- **Hidden coupling:** ConnectionsImpl must know about Frame structure

### ❌ Approach 2: Don't Use send(channel, msg) - Comment It Out

**Implementation by other teams:**
- Leave `send(String channel, T msg)` empty with a comment
- Force protocol layer to handle everything

**Problems:**
- Interface method exists but doesn't work as expected
- No guidance for developers on what to use instead
- Wastes interface definition

### ✅ Approach 3: Protocol Layer Creates Per-Subscriber Frames (IMPLEMENTED)

**Our implementation:**
- Protocol layer gets all subscribers via `getChannelSubscribers(channel)`
- For each subscriber, creates a unique MESSAGE frame with their subscription-id
- Sends each frame individually via `connections.send(connectionId, frame)`
- `send(String channel, T msg)` kept for potential future use with warning comment

**Benefits:**
- ✅ **Thread-safe:** Each Frame is independent
- ✅ **Correct:** Each subscriber gets their proper subscription-id
- ✅ **Clear separation:** Protocol layer controls message format
- ✅ **Maintainable:** Clear code flow, easy to debug

## Implementation Details

### 1. ConnectionsImpl Changes

#### Added Method: `getChannelSubscribers()`

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

**Purpose:** Expose channel subscription data to protocol layer for iteration.

#### Modified Method: `send(String channel, T msg)`

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

**Purpose:** Document that this method is not suitable for MESSAGE frames, but keep it functional for potential future use.

### 2. StompMessagingProtocolImpl Implementation

#### Message ID Generation

```java
// Static message ID counter shared across all protocol instances
private static final AtomicInteger messageIdCounter = new AtomicInteger(0);
```

**Rationale:**
- No need to modify Database.java (keeps concerns separated)
- Static ensures uniqueness across all connections
- AtomicInteger provides thread-safe incrementing

#### handleSend() Implementation

```java
private void handleSend(Frame frame) {
    String destination = frame.getHeader("destination");
    
    if (destination == null) {
        sendError("Missing destination header", frame.getHeader("receipt"));
        return;
    }
    
    // Check if client is subscribed to destination
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
```

**Key Points:**
1. **Single message-id:** All subscribers receive the same message-id (identifies the message)
2. **Unique subscription headers:** Each subscriber gets their own subscription-id
3. **Direct sending:** Uses `send(connectionId, frame)` not `send(channel, frame)`
4. **Frame independence:** Each `Frame.createMessage()` call creates a new object

### 3. Frame.createMessage() Helper

```java
public static Frame createMessage(int messageId, String destination, int subscriptionId, String body) {
    Map<String, String> headers = new HashMap<>();
    headers.put("message-id", String.valueOf(messageId));
    headers.put("destination", destination);
    headers.put("subscription", String.valueOf(subscriptionId));
    return new Frame("MESSAGE", headers, body);
}
```

**This method already existed in Frame.java** - perfect for Approach 3!

## Performance Considerations

### Memory Usage

**Per broadcast to N subscribers:**
- Creates N Frame objects (vs 1 mutated Frame)
- Each Frame has ~3 headers + body string reference
- Overhead: ~100-200 bytes per Frame

**Example:** 100 subscribers, 1KB message body
- Approach 1 (mutated): ~1KB + 1 Frame object = ~1.2KB
- Approach 3 (unique): ~1KB body (shared) + 100 Frames × 200 bytes = ~21KB

**Verdict:** For typical scenarios (10-100 subscribers), memory overhead is negligible compared to benefits of correctness and thread-safety.

### Thread Safety

**Approach 1 (mutated Frame):**
- ❌ Multiple reactor threads could mutate same Frame
- ❌ Race conditions on header map access
- ❌ Subscribers see incorrect subscription-ids

**Approach 3 (unique Frames):**
- ✅ Each Frame is independent
- ✅ No shared mutable state
- ✅ Reactor threads can safely process different subscribers in parallel

## Comparison Table

| Aspect | Approach 1 (Mutated) | Approach 2 (Disabled) | Approach 3 (Unique) ✅ |
|--------|---------------------|----------------------|----------------------|
| **Thread Safety** | ❌ Race conditions | ✅ N/A | ✅ Safe |
| **Correctness** | ❌ Wrong subscription-ids | ✅ Correct | ✅ Correct |
| **Memory Usage** | ✅ Minimal (1 Frame) | ✅ Minimal | ⚠️ N×Frame |
| **Separation of Concerns** | ❌ ConnectionsImpl knows Frame | ✅ Protocol handles all | ✅ Protocol handles all |
| **Code Clarity** | ⚠️ Hidden mutation | ⚠️ Empty method | ✅ Clear flow |
| **Maintainability** | ❌ Confusing behavior | ⚠️ No guidance | ✅ Well documented |

## Testing Scenarios

### Scenario 1: Multiple Subscribers, Same Channel

```
Setup:
  - Client A: SUBSCRIBE destination:/topic/test id:10
  - Client B: SUBSCRIBE destination:/topic/test id:20
  - Client C: SUBSCRIBE destination:/topic/test id:30
  
Action:
  - Client A: SEND destination:/topic/test body:"Hello"
  
Expected Results:
  - Client A receives: MESSAGE subscription:10 message-id:1 destination:/topic/test body:Hello
  - Client B receives: MESSAGE subscription:20 message-id:1 destination:/topic/test body:Hello
  - Client C receives: MESSAGE subscription:30 message-id:1 destination:/topic/test body:Hello
```

### Scenario 2: Concurrent Sends to Different Channels

```
Setup:
  - Client A: SUBSCRIBE /topic/sports id:1, /topic/news id:2
  - Client B: SUBSCRIBE /topic/sports id:3
  
Action (concurrent):
  - Thread 1: SEND destination:/topic/sports body:"Goal!"
  - Thread 2: SEND destination:/topic/news body:"Breaking"
  
Expected Results (no race conditions):
  - Client A receives on sports: MESSAGE subscription:1
  - Client A receives on news: MESSAGE subscription:2
  - Client B receives on sports: MESSAGE subscription:3
```

## Conclusion

**Approach 3** provides the best balance of correctness, thread-safety, and maintainability. While it uses slightly more memory than a mutated-Frame approach, the benefits far outweigh the cost:

1. ✅ **Correct STOMP protocol implementation**
2. ✅ **Thread-safe for Reactor server**
3. ✅ **Clear separation of concerns**
4. ✅ **Easy to understand and debug**
5. ✅ **No modifications to Database.java required**

The implementation is complete and ready for testing with the STOMP client.
