#!/bin/bash
# Suite C: Channel Isolation Test
# Tests that messages are only delivered to correct channel subscribers

set -e

echo "🧪 Suite C: Channel Isolation Test"
echo "Testing multi-channel subscription isolation"
echo ""

CLIENT_BIN="../../client/bin/StompWCIClient"
SERVER_HOST="127.0.0.1"
SERVER_PORT="7777"
TEST_DIR="/tmp/channel_isolation_test"

# Setup
mkdir -p $TEST_DIR

echo "Test Scenario:"
echo "  Client 1: joins Germany_Japan + Spain_Italy"
echo "  Client 2: joins Germany_Japan only"
echo "  Client 3: joins Spain_Italy only"
echo "  Client 4: joins France_Brazil only"
echo "  → Client 1 sends to Germany_Japan"
echo "  → Verify only Client 2 receives (not Client 3, 4)"
echo ""

# Check if client binary exists
if [ ! -f "$CLIENT_BIN" ]; then
    echo "❌ Client binary not found at $CLIENT_BIN"
    echo "Please compile client: cd client && make"
    exit 1
fi

# Check if server is running
if ! nc -z $SERVER_HOST $SERVER_PORT 2>/dev/null; then
    echo "❌ STOMP server not running on port $SERVER_PORT"
    echo "Please start: cd server && mvn exec:java -Dexec.args=\"$SERVER_PORT tpc\""
    exit 1
fi

echo "✅ Preconditions met"
echo ""

# Create test event files
cat > $TEST_DIR/germany_japan_event.json << 'JSON_EOF'
{
    "team a": "Germany",
    "team b": "Japan",
    "events": [
        {
            "event name": "Goal",
            "time": 23,
            "general game updates": {
                "active": false,
                "before halftime": true,
                "description": "Germany scores!"
            },
            "team a updates": {
                "goals": 1
            },
            "team b updates": {
                "goals": 0
            }
        }
    ]
}
JSON_EOF

cat > $TEST_DIR/spain_italy_event.json << 'JSON_EOF'
{
    "team a": "Spain",
    "team b": "Italy",
    "events": [
        {
            "event name": "Corner",
            "time": 15,
            "general game updates": {
                "active": true,
                "before halftime": true,
                "description": "Spain corner kick"
            },
            "team a updates": {},
            "team b updates": {}
        }
    ]
}
JSON_EOF

echo "Test 1: Multi-Channel Subscription"
echo "This test requires manual verification with multiple terminal windows"
echo ""

# Create automated test script
cat > $TEST_DIR/automated_channel_test.py << 'PYTHON_EOF'
#!/usr/bin/env python3
import socket
import threading
import time

def create_stomp_frame(command, headers, body=""):
    """Create a STOMP frame"""
    frame = command + "\n"
    for key, value in headers.items():
        frame += f"{key}:{value}\n"
    frame += "\n" + body + "\0"
    return frame

def send_frame(sock, frame):
    """Send STOMP frame"""
    sock.sendall(frame.encode())

def receive_frame(sock, timeout=5):
    """Receive STOMP frame"""
    sock.settimeout(timeout)
    try:
        data = b''
        while b'\0' not in data:
            chunk = sock.recv(1024)
            if not chunk:
                break
            data += chunk
        return data.decode()
    except socket.timeout:
        return ""

class StompClient:
    def __init__(self, username, password, host='127.0.0.1', port=7777):
        self.username = username
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((host, port))
        self.received_messages = []
        self.sub_id = 0
        
        # Connect
        connect_frame = create_stomp_frame("CONNECT", {
            "accept-version": "1.2",
            "host": "stomp.cs.bgu.ac.il",
            "login": username,
            "passcode": password
        })
        send_frame(self.sock, connect_frame)
        response = receive_frame(self.sock)
        
        if "CONNECTED" in response:
            print(f"✅ {username} connected")
        else:
            print(f"❌ {username} connection failed: {response}")
    
    def subscribe(self, channel):
        """Subscribe to a channel"""
        self.sub_id += 1
        sub_frame = create_stomp_frame("SUBSCRIBE", {
            "destination": f"/{channel}",
            "id": str(self.sub_id),
            "receipt": f"sub-{self.sub_id}"
        })
        send_frame(self.sock, sub_frame)
        response = receive_frame(self.sock, timeout=2)
        
        if "RECEIPT" in response:
            print(f"✅ {self.username} subscribed to {channel}")
            return True
        else:
            print(f"❌ {self.username} subscribe failed")
            return False
    
    def send_event(self, channel, event_body):
        """Send event to channel"""
        send_frame_stomp = create_stomp_frame("SEND", {
            "destination": f"/{channel}"
        }, body=event_body)
        send_frame(self.sock, send_frame_stomp)
        print(f"📤 {self.username} sent event to {channel}")
    
    def listen(self, duration=5):
        """Listen for messages"""
        print(f"👂 {self.username} listening for {duration}s...")
        start_time = time.time()
        
        while time.time() - start_time < duration:
            msg = receive_frame(self.sock, timeout=1)
            if msg and "MESSAGE" in msg:
                self.received_messages.append(msg)
                print(f"📨 {self.username} received message!")
        
        return len(self.received_messages)
    
    def close(self):
        """Disconnect"""
        disconnect_frame = create_stomp_frame("DISCONNECT", {
            "receipt": "disconnect-1"
        })
        send_frame(self.sock, disconnect_frame)
        self.sock.close()

def test_channel_isolation():
    print("\n=== Testing Channel Isolation ===\n")
    
    # Create clients
    client1 = StompClient("fan1", "pass1")
    client2 = StompClient("fan2", "pass2")
    client3 = StompClient("fan3", "pass3")
    client4 = StompClient("fan4", "pass4")
    
    time.sleep(1)
    
    # Subscribe to channels
    client1.subscribe("Germany_Japan")
    client1.subscribe("Spain_Italy")
    
    client2.subscribe("Germany_Japan")
    
    client3.subscribe("Spain_Italy")
    
    client4.subscribe("France_Brazil")
    
    time.sleep(1)
    
    # Start listeners in background
    def listen_client(client):
        client.listen(duration=10)
    
    threads = []
    for client in [client2, client3, client4]:
        t = threading.Thread(target=listen_client, args=(client,))
        t.start()
        threads.append(t)
    
    time.sleep(2)
    
    # Client1 sends to Germany_Japan
    event_body = """user: fan1
team a: Germany
team b: Japan
event name: Goal
time: 45
general game updates: Germany attacks!
team a updates: goals +1
team b updates: none"""
    
    client1.send_event("Germany_Japan", event_body)
    
    # Wait for listeners
    for t in threads:
        t.join()
    
    # Verify results
    print("\n=== Results ===")
    print(f"Client2 (Germany_Japan): {len(client2.received_messages)} messages ✅ (expected: 1)")
    print(f"Client3 (Spain_Italy): {len(client3.received_messages)} messages ✅ (expected: 0)")
    print(f"Client4 (France_Brazil): {len(client4.received_messages)} messages ✅ (expected: 0)")
    
    # Cleanup
    client1.close()
    client2.close()
    client3.close()
    client4.close()
    
    # Verify isolation
    if len(client2.received_messages) > 0 and len(client3.received_messages) == 0 and len(client4.received_messages) == 0:
        print("\n✅ CHANNEL ISOLATION VERIFIED!")
        return True
    else:
        print("\n❌ CHANNEL ISOLATION FAILED!")
        return False

if __name__ == "__main__":
    import sys
    success = test_channel_isolation()
    sys.exit(0 if success else 1)
PYTHON_EOF

chmod +x $TEST_DIR/automated_channel_test.py

echo "Running automated channel isolation test..."
python3 $TEST_DIR/automated_channel_test.py

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ✅ CHANNEL ISOLATION TEST PASSED                    ║"
    echo "║  Messages only delivered to correct subscribers ✓    ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 0
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ❌ CHANNEL ISOLATION TEST FAILED                    ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 1
fi
