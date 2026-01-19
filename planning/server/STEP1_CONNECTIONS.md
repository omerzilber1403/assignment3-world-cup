# Task 1: Implement ConnectionsImpl<T>

## Goal
Create generic connection manager implementing `Connections<T>` interface.

## File Location
`server/src/main/java/bgu/spl/net/srv/ConnectionsImpl.java`

## Requirements

### Interface to Implement
```java
public interface Connections<T> {
    boolean send(int connectionId, T msg);
    void send(String channel, T msg);
    void disconnect(int connectionId);
}
```

### Data Structures Needed

```java
private final ConcurrentHashMap<Integer, ConnectionHandler<T>> handlers;
private final ConcurrentHashMap<String, ConcurrentHashMap<Integer, Integer>> channelSubscriptions;
private final ConcurrentHashMap<Integer, ConcurrentHashMap<String, Integer>> clientSubscriptions;
```

**Explanation:**
- `handlers`: connectionId → ConnectionHandler mapping
- `channelSubscriptions`: channel → (connectionId → subscriptionId) mapping
- `clientSubscriptions`: connectionId → (channel → subscriptionId) mapping

### Public Methods to Implement

#### 1. `boolean send(int connectionId, T msg)`
- Find handler by connectionId
- Call `handler.send(msg)`
- Return true if successful, false if connection not found
- Thread-safe: ConcurrentHashMap provides safety

#### 2. `void send(String channel, T msg)`
- Get all connectionIds subscribed to channel
- For each connectionId: call `send(connectionId, msg)`
- Thread-safe: iterate over snapshot of subscribers

#### 3. `void disconnect(int connectionId)`
- Remove from handlers map
- Remove from all channel subscriptions
- Remove from client subscriptions
- Close the handler
- Thread-safe: all operations atomic per map

#### 4. `void connect(int connectionId, ConnectionHandler<T> handler)`
- Add to handlers map
- Called by ConnectionHandler constructor

#### 5. `void subscribe(int connectionId, String channel, int subscriptionId)`
- Add to channelSubscriptions
- Add to clientSubscriptions
- Called by protocol when handling SUBSCRIBE frame

#### 6. `void unsubscribe(int connectionId, int subscriptionId)`
- Find channel by subscriptionId in clientSubscriptions
- Remove from both maps
- Called by protocol when handling UNSUBSCRIBE frame

## Implementation Steps

1. Create class skeleton with fields
2. Implement constructor
3. Implement `connect()` and `disconnect()`
4. Implement `send(connectionId, msg)`
5. Implement `send(channel, msg)`
6. Implement `subscribe()` and `unsubscribe()`

## Testing Considerations

- After implementation, server code compiles but doesn't run yet (needs Tasks 2-3)
- No unit test needed at this stage (integration test after Task 4)
- Focus on thread-safety and correct data structure management

## Next Step
→ After completing this task, proceed to STEP2_TPC.md
