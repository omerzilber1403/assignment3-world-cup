# Task 2: Refactor Thread-Per-Client Server

## Goal
Integrate ConnectionsImpl into BaseServer and BlockingConnectionHandler, support StompMessagingProtocol.

## Files to Modify

1. `server/src/main/java/bgu/spl/net/srv/BaseServer.java`
2. `server/src/main/java/bgu/spl/net/srv/BlockingConnectionHandler.java`

## Part A: BaseServer.java Changes

### Add Fields
```java
protected final ConnectionsImpl<T> connections;
private final AtomicInteger connectionIdCounter;
```

### Modify Constructor
- Initialize `connections = new ConnectionsImpl<>()`
- Initialize `connectionIdCounter = new AtomicInteger(0)`

### Modify serve() Method
```java
while (!Thread.currentThread().isInterrupted()) {
    Socket clientSock = serverSock.accept();
    
    int connectionId = connectionIdCounter.incrementAndGet();
    
    BlockingConnectionHandler<T> handler = new BlockingConnectionHandler<>(
        clientSock,
        encdecFactory.get(),
        protocolFactory.get(),
        connectionId,
        connections
    );
    
    execute(handler);
}
```

## Part B: BlockingConnectionHandler.java Changes

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
public BlockingConnectionHandler(
    Socket sock,
    MessageEncoderDecoder<T> reader,
    StompMessagingProtocol<T> protocol,
    int connectionId,
    Connections<T> connections
) {
    this.sock = sock;
    this.encdec = reader;
    this.protocol = protocol;
    this.connectionId = connectionId;
    this.connections = connections;
    
    // Register with connections
    this.connections.connect(connectionId, this);
}
```

### Modify run() Method
Add start() call before loop:
```java
@Override
public void run() {
    try (Socket sock = this.sock) {
        int read;
        in = new BufferedInputStream(sock.getInputStream());
        out = new BufferedOutputStream(sock.getOutputStream());
        
        // Initialize protocol with connectionId and connections
        protocol.start(connectionId, connections);
        
        while (!protocol.shouldTerminate() && connected && (read = in.read()) >= 0) {
            T nextMessage = encdec.decodeNextByte((byte) read);
            if (nextMessage != null) {
                protocol.process(nextMessage); // void return now
            }
        }
    } catch (IOException ex) {
        ex.printStackTrace();
    }
}
```

### Implement send() Method
```java
@Override
public void send(T msg) {
    try {
        synchronized (out) {
            out.write(encdec.encode(msg));
            out.flush();
        }
    } catch (IOException e) {
        e.printStackTrace();
    }
}
```

### Modify close() Method
```java
@Override
public void close() throws IOException {
    connected = false;
    connections.disconnect(connectionId);
    sock.close();
}
```

## Key Changes Summary

1. **Protocol Type:** `MessagingProtocol` → `StompMessagingProtocol`
2. **Process Return:** `T response = protocol.process(msg)` → `protocol.process(msg)` (void)
3. **Initialization:** Added `protocol.start()` call
4. **Push Messages:** Implemented `send(T msg)` for server-initiated sends
5. **Connection Management:** Register/unregister with ConnectionsImpl

## Compilation Check

After these changes:
- Code should compile successfully
- Echo example will be broken (uses old MessagingProtocol)
- STOMP server not runnable yet (needs StompMessagingProtocol implementation)

## Next Step
→ After completing this task, proceed to STEP3_REACTOR.md
