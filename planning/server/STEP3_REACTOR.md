# Task 3: Refactor Reactor Server

## Goal
Integrate ConnectionsImpl into Reactor and NonBlockingConnectionHandler, support StompMessagingProtocol.

## Files to Modify

1. `server/src/main/java/bgu/spl/net/srv/Reactor.java`
2. `server/src/main/java/bgu/spl/net/srv/NonBlockingConnectionHandler.java`

## Part A: Reactor.java Changes

### Add Fields
```java
private final ConnectionsImpl<T> connections;
private final AtomicInteger connectionIdCounter;
```

### Modify Constructor
```java
public Reactor(
    int numThreads,
    int port,
    Supplier<MessagingProtocol<T>> protocolFactory,
    Supplier<MessageEncoderDecoder<T>> readerFactory
) {
    this.pool = new ActorThreadPool(numThreads);
    this.port = port;
    this.protocolFactory = protocolFactory;
    this.readerFactory = readerFactory;
    this.connections = new ConnectionsImpl<>();
    this.connectionIdCounter = new AtomicInteger(0);
}
```

### Modify handleAccept() Method
```java
private void handleAccept(ServerSocketChannel serverChan, Selector selector) throws IOException {
    SocketChannel clientChan = serverChan.accept();
    clientChan.configureBlocking(false);
    
    int connectionId = connectionIdCounter.incrementAndGet();
    
    NonBlockingConnectionHandler<T> handler = new NonBlockingConnectionHandler<>(
        readerFactory.get(),
        protocolFactory.get(),
        clientChan,
        this,
        connectionId,
        connections
    );
    
    clientChan.register(selector, SelectionKey.OP_READ, handler);
}
```

## Part B: NonBlockingConnectionHandler.java Changes

### Change Field Type
```java
// OLD
private final MessagingProtocol<T> protocol;

// NEW
private final StompMessagingProtocol<T> protocol;
```

### Add New Fields
```java
private final int connectionId;
private final Connections<T> connections;
```

### Modify Constructor
```java
public NonBlockingConnectionHandler(
    MessageEncoderDecoder<T> reader,
    StompMessagingProtocol<T> protocol,
    SocketChannel chan,
    Reactor reactor,
    int connectionId,
    Connections<T> connections
) {
    this.chan = chan;
    this.encdec = reader;
    this.protocol = protocol;
    this.reactor = reactor;
    this.connectionId = connectionId;
    this.connections = connections;
    
    // Register with connections
    this.connections.connect(connectionId, this);
    
    // Initialize protocol (safe to call in constructor)
    this.protocol.start(connectionId, connections);
}
```

### Modify continueRead() Method
Remove response handling:
```java
public Runnable continueRead() {
    ByteBuffer buf = leaseBuffer();
    
    boolean success = false;
    try {
        success = chan.read(buf) != -1;
    } catch (IOException ex) {
        ex.printStackTrace();
    }
    
    if (success) {
        buf.flip();
        return () -> {
            try {
                while (buf.hasRemaining()) {
                    T nextMessage = encdec.decodeNextByte(buf.get());
                    if (nextMessage != null) {
                        protocol.process(nextMessage); // void return
                    }
                }
            } finally {
                releaseBuffer(buf);
            }
        };
    } else {
        releaseBuffer(buf);
        close();
        return null;
    }
}
```

### Implement send() Method
```java
@Override
public void send(T msg) {
    writeQueue.add(ByteBuffer.wrap(encdec.encode(msg)));
    reactor.updateInterestedOps(chan, SelectionKey.OP_READ | SelectionKey.OP_WRITE);
}
```

### Modify close() Method
```java
public void close() {
    try {
        connections.disconnect(connectionId);
        chan.close();
    } catch (IOException ex) {
        ex.printStackTrace();
    }
}
```

## Key Changes Summary

1. **Protocol Type:** `MessagingProtocol` → `StompMessagingProtocol`
2. **Process Return:** Removed response handling from `continueRead()`
3. **Initialization Timing:** Call `protocol.start()` in constructor (not from selector thread)
4. **Push Messages:** Implemented `send(T msg)` for server-initiated sends
5. **Connection Management:** Register/unregister with ConnectionsImpl

## Critical Note: start() Timing

Calling `protocol.start()` in constructor is safe because:
- Constructor runs on selector thread
- But start() completes before any `continueRead()` tasks submitted
- First message processing task sees protocol already initialized
- No race condition possible

## Compilation Check

After these changes:
- Code should compile successfully
- Both TPC and Reactor servers ready for STOMP protocol
- Need Task 4 to make it runnable

## Next Step
→ After completing this task, proceed to STEP4_STOMP.md
