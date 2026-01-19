# STOMP Server Implementation Plan

## Overview
Implement STOMP server in 4 sequential tasks as specified in assignment section 3.2.

## Architecture Summary

```
Connections<T> (interface) ────┬──► ConnectionsImpl<T> (generic implementation)
                               │
StompMessagingProtocol<T> ─────┤
                               │
ConnectionHandler<T> ───────────┘
    ├─► BlockingConnectionHandler (TPC)
    └─► NonBlockingConnectionHandler (Reactor)

T = Frame (STOMP message representation)
```

## Task Sequence

### Task 1: Implement ConnectionsImpl<T>
**Status:** Not Started  
**File:** `server/src/main/java/bgu/spl/net/srv/ConnectionsImpl.java`  
**Goal:** Generic connection manager that holds all active ConnectionHandlers and manages channel subscriptions.

### Task 2: Refactor TPC Server
**Status:** Not Started  
**Files:** `BaseServer.java`, `BlockingConnectionHandler.java`  
**Goal:** Integrate ConnectionsImpl, add connectionId generation, support StompMessagingProtocol interface.

### Task 3: Refactor Reactor Server
**Status:** Not Started  
**Files:** `Reactor.java`, `NonBlockingConnectionHandler.java`  
**Goal:** Same as Task 2 but for reactor pattern.

### Task 4: Implement STOMP Protocol
**Status:** Not Started  
**Files:** `Frame.java`, `StompEncoderDecoder.java`, `StompProtocolImpl.java`, `StompServer.java`  
**Goal:** Complete STOMP protocol handling (CONNECT, SEND, SUBSCRIBE, UNSUBSCRIBE, DISCONNECT).

## Critical Design Decisions

1. **Generic Implementation:** All server code stays generic on `T`, no hardcoding to Frame
2. **Interface Change:** ConnectionHandlers switch from `MessagingProtocol<T>` to `StompMessagingProtocol<T>`
3. **Thread Safety:** ConnectionsImpl must be thread-safe (use ConcurrentHashMap)
4. **Timing:** Call sequence must be: `new Handler()` → `connections.connect()` → `protocol.start()` → `process()`

## Testing Strategy

1. After Task 1-3: Fix Echo example to work with new interfaces
2. After Task 4: Run STOMP server with client
3. Test both TPC and Reactor modes

## Next Step
→ See STEP1_CONNECTIONS.md for detailed Task 1 implementation guide
