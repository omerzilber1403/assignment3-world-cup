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
    switch (frame.getCommand()) {
        case "CONNECT": handleConnect(frame); break;
        case "SEND": handleSend(frame); break;
        case "SUBSCRIBE": handleSubscribe(frame); break;
        case "UNSUBSCRIBE": handleUnsubscribe(frame); break;
        case "DISCONNECT": handleDisconnect(frame); break;
    }
}
```

### Command Handlers

#### handleConnect()
- Check username not already logged in
- Store username
- Send CONNECTED frame

#### handleSend()
- Get destination from headers
- Create MESSAGE frame
- Call `connections.send(destination, messageFrame)`

#### handleSubscribe()
- Get destination and id from headers
- Store subscription mapping
- Call `connections.subscribe(connectionId, destination, subscriptionId)`
- Send RECEIPT if receipt header present

#### handleUnsubscribe()
- Get id from headers
- Find destination from stored mapping
- Call `connections.unsubscribe(connectionId, subscriptionId)`
- Send RECEIPT if receipt header present

#### handleDisconnect()
- Send RECEIPT if receipt header present
- Set shouldTerminate = true
- Connection will close automatically

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

1. Frame.java (parse and toString)
2. StompEncoderDecoder.java (state machine)
3. StompProtocolImpl.java (command handlers)
4. StompServer.java (main method)

## Next Step
→ After completing this task, server is fully functional. Test with client.
