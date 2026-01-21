#!/bin/bash
# Suite A: Stress Test - 10 Concurrent Clients
# Tests server stability with multiple simultaneous clients

set -e

echo "🧪 Suite A: 10 Concurrent Clients Stress Test"
echo "Testing server with heavy concurrent load"
echo ""

TEST_DIR="/tmp/stress_test_10_clients"
mkdir -p $TEST_DIR

echo "Test Configuration:"
echo "  - 10 concurrent clients"
echo "  - Each joins 2-3 channels"
echo "  - Each sends 10 events"
echo "  - Total: ~100 messages through system"
echo ""

# Create stress test script
cat > $TEST_DIR/stress_test.py << 'PYTHON_EOF'
#!/usr/bin/env python3
import socket
import threading
import time
import random

def create_frame(command, headers, body=""):
    frame = command + "\n"
    for k, v in headers.items():
        frame += f"{k}:{v}\n"
    frame += "\n" + body + "\0"
    return frame

class StressClient:
    def __init__(self, client_id, host='127.0.0.1', port=7777):
        self.client_id = client_id
        self.username = f"stressuser{client_id}"
        self.events_sent = 0
        self.messages_received = 0
        self.errors = []
        
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((host, port))
            self.sock.settimeout(5)
            
            # Connect
            frame = create_frame("CONNECT", {
                "accept-version": "1.2",
                "host": "stomp.cs.bgu.ac.il",
                "login": self.username,
                "passcode": f"pass{client_id}"
            })
            self.sock.sendall(frame.encode())
            
            response = self.sock.recv(1024)
            if b"CONNECTED" in response:
                print(f"✅ Client {client_id} connected")
            else:
                self.errors.append(f"Connection failed: {response}")
                
        except Exception as e:
            self.errors.append(f"Init error: {e}")
    
    def subscribe_channels(self, num_channels):
        """Subscribe to multiple channels"""
        channels = ["Germany_Japan", "Spain_Italy", "France_Brazil", "USA_Mexico", "Brazil_Argentina"]
        selected = random.sample(channels, min(num_channels, len(channels)))
        
        for i,  channel in enumerate(selected):
            try:
                frame = create_frame("SUBSCRIBE", {
                    "destination": f"/{channel}",
                    "id": str(i+1)
                })
                self.sock.sendall(frame.encode())
                time.sleep(0.1)
            except Exception as e:
                self.errors.append(f"Subscribe error: {e}")
    
    def send_events(self, num_events):
        """Send multiple events"""
        for i in range(num_events):
            try:
                body = f"""user: {self.username}
team a: Germany
team b: Japan
event name: Event{i}
time: {i*10}
general game updates: Stress test event {i}
team a updates: none
team b updates: none"""
                
                frame = create_frame("SEND", {
                    "destination": "/Germany_Japan"
                }, body=body)
                
                self.sock.sendall(frame.encode())
                self.events_sent += 1
                time.sleep(0.05)  # Small delay to avoid overwhelming
                
            except Exception as e:
                self.errors.append(f"Send error: {e}")
    
    def listen(self, duration):
        """Listen for incoming messages"""
        end_time = time.time() + duration
        self.sock.settimeout(1)
        
        while time.time() < end_time:
            try:
                data = self.sock.recv(4096)
                if data and b"MESSAGE" in data:
                    self.messages_received += 1
            except socket.timeout:
                continue
            except Exception as e:
                self.errors.append(f"Listen error: {e}")
                break
    
    def disconnect(self):
        """Disconnect from server"""
        try:
            frame = create_frame("DISCONNECT", {})
            self.sock.sendall(frame.encode())
            self.sock.close()
        except:
            pass
    
    def get_stats(self):
        return {
            "id": self.client_id,
            "sent": self.events_sent,
            "received": self.messages_received,
            "errors": len(self.errors)
        }

def run_client(client_id, results):
    """Run a single stress test client"""
    client = StressClient(client_id)
    
    # Subscribe to 2-3 channels
    num_channels = random.randint(2, 3)
    client.subscribe_channels(num_channels)
    
    time.sleep(1)
    
    # Start listening in background
    def listen_bg():
        client.listen(duration=15)
    
    listener = threading.Thread(target=listen_bg)
    listener.start()
    
    # Send events
    time.sleep(1)
    client.send_events(10)
    
    # Wait for listener
    listener.join()
    
    # Disconnect
    client.disconnect()
    
    results.append(client.get_stats())

def stress_test_10_clients():
    print("\n=== Running 10 Concurrent Clients ===\n")
    
    NUM_CLIENTS = 10
    results = []
    threads = []
    
    # Launch all clients concurrently
    start_time = time.time()
    
    for i in range(NUM_CLIENTS):
        t = threading.Thread(target=run_client, args=(i, results))
        threads.append(t)
        t.start()
        time.sleep(0.2)  # Stagger slightly
    
    # Wait for all clients
    for t in threads:
        t.join()
    
    duration = time.time() - start_time
    
    # Analyze results
    print("\n=== Stress Test Results ===")
    print(f"Duration: {duration:.2f}s\n")
    
    total_sent = 0
    total_received = 0
    total_errors = 0
    
    for r in results:
        print(f"Client {r['id']}: sent={r['sent']}, received={r['received']}, errors={r['errors']}")
        total_sent += r['sent']
        total_received += r['received']
        total_errors += r['errors']
    
    print(f"\n📊 Summary:")
    print(f"   Total events sent: {total_sent}")
    print(f"   Total messages received: {total_received}")
    print(f"   Total errors: {total_errors}")
    
    # Success criteria
    success = (
        total_sent >= 90 and  # At least 90% of 100 events sent
        total_errors == 0       # No errors
    )
    
    if success:
        print(f"\n✅ STRESS TEST PASSED!")
        print(f"   Server handled {NUM_CLIENTS} concurrent clients successfully")
        return True
    else:
        print(f"\n❌ STRESS TEST FAILED")
        print(f"   Errors occurred or insufficient events sent")
        return False

if __name__ == "__main__":
    import sys
    
    # Check server
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(('127.0.0.1', 7777))
        sock.close()
    except:
        print("❌ Server not running on port 7777")
        sys.exit(1)
    
    success = stress_test_10_clients()
    sys.exit(0 if success else 1)
PYTHON_EOF

python3 $TEST_DIR/stress_test.py

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ✅ 10-CLIENT STRESS TEST PASSED                     ║"
    echo "║  Server stable under concurrent load ✓               ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 0
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ❌ STRESS TEST FAILED                               ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 1
fi
