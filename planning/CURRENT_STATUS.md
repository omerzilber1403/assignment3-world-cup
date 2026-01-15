# Implementation Status Tracker

## Current Status: Planning Complete

---

## Task 1: ConnectionsImpl<T>
**Status:** NOT STARTED  
**File:** `server/src/main/java/bgu/spl/net/srv/ConnectionsImpl.java`

- [ ] Create class skeleton
- [ ] Implement connect() and disconnect()
- [ ] Implement send(connectionId, msg)
- [ ] Implement send(channel, msg)
- [ ] Implement subscribe() and unsubscribe()

---

## Task 2: TPC Server Refactoring
**Status:** NOT STARTED  
**Files:** `BaseServer.java`, `BlockingConnectionHandler.java`

### BaseServer.java
- [ ] Add ConnectionsImpl field
- [ ] Add connectionIdCounter field
- [ ] Modify constructor
- [ ] Modify serve() method

### BlockingConnectionHandler.java
- [ ] Change protocol type to StompMessagingProtocol
- [ ] Add connectionId and connections fields
- [ ] Modify constructor
- [ ] Add protocol.start() call in run()
- [ ] Implement send() method
- [ ] Modify close() method

---

## Task 3: Reactor Server Refactoring
**Status:** NOT STARTED  
**Files:** `Reactor.java`, `NonBlockingConnectionHandler.java`

### Reactor.java
- [ ] Add ConnectionsImpl field
- [ ] Add connectionIdCounter field
- [ ] Modify constructor
- [ ] Modify handleAccept() method

### NonBlockingConnectionHandler.java
- [ ] Change protocol type to StompMessagingProtocol
- [ ] Add connectionId and connections fields
- [ ] Modify constructor
- [ ] Add protocol.start() call
- [ ] Modify continueRead() method
- [ ] Implement send() method
- [ ] Modify close() method

---

## Task 4: STOMP Protocol Implementation
**Status:** NOT STARTED  
**Files:** `Frame.java`, `StompEncoderDecoder.java`, `StompProtocolImpl.java`, `StompServer.java`

### Frame.java
- [ ] Create class with command, headers, body
- [ ] Implement parse() method
- [ ] Implement toString() method

### StompEncoderDecoder.java
- [ ] Implement state machine
- [ ] Implement decodeNextByte()
- [ ] Implement encode()

### StompProtocolImpl.java
- [ ] Implement start() method
- [ ] Implement process() method
- [ ] Implement handleConnect()
- [ ] Implement handleSend()
- [ ] Implement handleSubscribe()
- [ ] Implement handleUnsubscribe()
- [ ] Implement handleDisconnect()

### StompServer.java
- [ ] Implement main() method
- [ ] Add argument parsing
- [ ] Add server instantiation logic

---

## Testing
- [ ] Compile successfully (mvn compile)
- [ ] Run TPC server
- [ ] Run Reactor server
- [ ] Test with client

---

**Last Updated:** Not started yet
