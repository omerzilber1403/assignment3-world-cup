#!/bin/bash
# Suite C: Channel Broadcast Test
# Tests that all channel subscribers receive messages

set -e

echo "🧪 Suite C: Channel Broadcast Test"
echo "Testing broadcast to all channel subscribers"
echo ""

TEST_DIR="/tmp/channel_broadcast_test"
mkdir -p $TEST_DIR

echo "Test Scenario:"
echo "  5 clients all join 'Germany_Japan' channel"
echo "  Client 1 sends an event"
echo "  → Verify all OTHER 4 clients receive the message"
echo ""

# Create automated broadcast test
cat > $TEST_DIR/broadcast_test.py << 'PYTHON_EOF'
#!/usr/bin/env python3
import socket
import threading
import time

def create_stomp_frame(command, headers, body=""):
    frame = command + "\n"
    for key, value in headers.items():
        frame += f"{key}:{value}\n"
    frame += "\n" + body + "\0"
    return frame

class SimpleStompClient:
    def __init__(self, username, host='127.0.0.1', port=7777):
        self.username = username
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((host, port))
        self.messages = []
        
        # Connect
        frame = create_stomp_frame("CONNECT", {
            "accept-version": "1.2",
            "host": "stomp.cs.bgu.ac.il",
            "login": username,
            "passcode": f"pass_{username}"
        })
        self.sock.sendall(frame.encode())
        
        # Receive CONNECTED
        self.sock.settimeout(3)
        data = self.sock.recv(1024)
        if b"CONNECTED" in data:
            print(f"✅ {username} connected")
    
    def subscribe(self, channel):
        frame = create_stomp_frame("SUBSCRIBE", {
            "destination": f"/{channel}",
            "id": "1"
        })
        self.sock.sendall(frame.encode())
        time.sleep(0.5)
        print(f"✅ {username} subscribed to {channel}")
    
    def send_message(self, channel, body):
        frame = create_stomp_frame("SEND", {
            "destination": f"/{channel}"
        }, body=body)
        self.sock.sendall(frame.encode())
        print(f"📤 {self.username} sent message to {channel}")
    
    def listen(self, duration=5):
        print(f"👂 {self.username} listening...")
        self.sock.settimeout(1)
        end_time = time.time() + duration
        
        while time.time() < end_time:
            try:
                data = self.sock.recv(4096)
                if data and b"MESSAGE" in data:
                    self.messages.append(data)
                    print(f"📨 {self.username} received message!")
            except socket.timeout:
                continue
        
        return len(self.messages)

def test_broadcast():
    print("\n=== Testing Channel Broadcast ===\n")
    
    NUM_CLIENTS = 5
    CHANNEL = "Germany_Japan"
    
    # Create clients
    clients = []
    for i in range(NUM_CLIENTS):
        client = SimpleStompClient(f"user{i}")
        clients.append(client)
    
    time.sleep(1)
    
    # All subscribe to same channel
    for client in clients:
        client.subscribe(CHANNEL)
    
    time.sleep(1)
    
    # Start listeners (except sender)
    def start_listening(client):
        client.listen(duration=8)
    
    listener_threads = []
    for client in clients[1:]:  # Skip first client (sender)
        t = threading.Thread(target=start_listening, args=(client,))
        t.start()
        listener_threads.append(t)
    
    time.sleep(2)
    
    # First client sends message
    message_body = """user: user0
team a: Germany
team b: Japan
event name: Kick Off
time: 0
general game updates: Match started!
team a updates: none
team b updates: none"""
    
    clients[0].send_message(CHANNEL, message_body)
    
    # Wait for all listeners
    for t in listener_threads:
        t.join()
    
    # Verify results
    print("\n=== Broadcast Results ===")
    received_count = 0
    for i, client in enumerate(clients[1:], 1):
        msg_count = len(client.messages)
        print(f"Client {i}: {msg_count} messages received")
        if msg_count > 0:
            received_count += 1
    
    print(f"\nTotal clients that received message: {received_count}/{NUM_CLIENTS-1}")
    
    if received_count == NUM_CLIENTS - 1:
        print("\n✅ BROADCAST VERIFIED: All subscribers received message!")
        return True
    else:
        print(f"\n❌ BROADCAST FAILED: Only {received_count} out of {NUM_CLIENTS-1} received")
        return False

if __name__ == "__main__":
    import sys
    try:
        success = test_broadcast()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ Test error: {e}")
        sys.exit(1)
PYTHON_EOF

# Check server running
if ! nc -z 127.0.0.1 7777 2>/dev/null; then
    echo "❌ STOMP server not running"
    exit 1
fi

python3 $TEST_DIR/broadcast_test.py

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ✅ CHANNEL BROADCAST TEST PASSED                    ║"
    echo "║  All subscribers received broadcast message ✓        ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 0
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ❌ CHANNEL BROADCAST TEST FAILED                    ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 1
fi
