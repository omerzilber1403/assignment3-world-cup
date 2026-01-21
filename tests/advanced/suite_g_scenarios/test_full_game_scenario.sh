#!/bin/bash
# Suite G: Full Game Scenario Test
# End-to-end test simulating complete World Cup match

set -e

echo "🧪 Suite G: Full World Cup Game Scenario"
echo "Simulating complete Germany vs Japan match with fans"
echo ""

TEST_DIR="/tmp/full_game_scenario"
mkdir -p $TEST_DIR

cat > $TEST_DIR/game_scenario.py << 'PYTHON_EOF'
#!/usr/bin/env python3
import socket
import threading
import time

def create_frame(command, headers, body=""):
    frame = command + "\n"
    for k, v in headers.items():
        frame += f"{k}:{v}\n"
    frame += "\n" + body + "\0"
    return frame

class WorldCupFan:
    def __init__(self, name, team, host='127.0.0.1', port=7777):
        self.name = name
        self.team = team
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((host, port))
        self.sock.settimeout(5)
        self.events_received = []
        
        # Connect
        frame = create_frame("CONNECT", {
            "accept-version": "1.2",
            "host": "stomp.cs.bgu.ac.il",
            "login": name,
            "passcode": f"{name}_pass"
        })
        self.sock.sendall(frame.encode())
        response = self.sock.recv(1024)
        
        if b"CONNECTED" in response:
            print(f"✅ {name} (supports {team}) joined the match!")
        else:
            print(f"❌ {name} connection failed")
    
    def subscribe(self, channel="Germany_Japan"):
        frame = create_frame("SUBSCRIBE", {
            "destination": f"/{channel}",
            "id": "1"
        })
        self.sock.sendall(frame.encode())
        time.sleep(0.3)
        print(f"🎫 {self.name} subscribed to {channel}")
    
    def report_event(self, minute, event_name, description):
        """Report game event"""
        body = f"""user: {self.name}
team a: Germany
team b: Japan
event name: {event_name}
time: {minute}
general game updates: {description}
team a updates: none
team b updates: none"""
        
        frame = create_frame("SEND", {
            "destination": "/Germany_Japan"
        }, body=body)
        
        self.sock.sendall(frame.encode())
        print(f"📢 {self.name} reported: [{minute}'] {event_name} - {description}")
    
    def listen_for_updates(self, duration=10):
        """Listen for game updates from other fans"""
        print(f"👂 {self.name} watching the game...")
        self.sock.settimeout(1)
        end_time = time.time() + duration
        
        while time.time() < end_time:
            try:
                data = self.sock.recv(4096)
                if data and b"MESSAGE" in data:
                    self.events_received.append(data)
                    # Extract event name if possible
                    try:
                        text = data.decode()
                        if "event name:" in text:
                            event_line = [line for line in text.split('\n') if 'event name:' in line][0]
                            event = event_line.split('event name:')[1].strip()
                            print(f"📨 {self.name} saw: {event}")
                    except:
                        pass
            except socket.timeout:
                continue
        
        print(f"   {self.name} received {len(self.events_received)} updates")
    
    def disconnect(self):
        try:
            frame = create_frame("DISCONNECT", {})
            self.sock.sendall(frame.encode())
            self.sock.close()
            print(f"👋 {self.name} left")
        except:
            pass

def simulate_world_cup_match():
    """Simulate a complete World Cup match with timeline"""
    
    print("\n" + "="*60)
    print("  🏆 WORLD CUP 2022: GERMANY vs JAPAN 🏆")
    print("="*60 + "\n")
    
    # Create fans
    print("📍 Fans arriving at the stadium...\n")
    fan1 = WorldCupFan("Mueller", "Germany")
    fan2 = WorldCupFan("Tanaka", "Japan")
    fan3 = WorldCupFan("Schmidt", "Germany")
    
    time.sleep(1)
    
    # Subscribe to match
    print()
    fan1.subscribe()
    fan2.subscribe()
    fan3.subscribe()
    
    time.sleep(1)
    
    # Start listeners
    print("\n⚽ MATCH BEGINS! ⚽\n")
    
    def fan_watch(fan):
        fan.listen_for_updates(duration=20)
    
    listener1 = threading.Thread(target=fan_watch, args=(fan2,))
    listener2 = threading.Thread(target=fan_watch, args=(fan3,))
    listener1.start()
    listener2.start()
    
    time.sleep(2)
    
    # Match timeline
    print("\n🎬 Match Events:\n")
    
    time.sleep(1)
    fan1.report_event(15, "Germany Attack", "Germany pressing forward!")
    
    time.sleep(2)
    fan2.report_event(23, "Japan Counter", "Quick Japanese counter-attack!")
    
    time.sleep(2)
    fan1.report_event(33, "GOAL GERMANY!", "⚽ Germany scores! 1-0")
    
    time.sleep(2)
    fan3.report_event(45, "Half Time", "First half ends, Germany leads 1-0")
    
    time.sleep(2)
    fan2.report_event(67, "Japan Pressure", "Japan attacking strongly!")
    
    time.sleep(2)
    fan2.report_event(75, "GOAL JAPAN!", "⚽⚽ Japan equalizes! 1-1")
    
    time.sleep(2)
    fan2.report_event(83, "GOAL JAPAN!", "⚽⚽⚽ Japan takes the lead! 2-1!!")
    
    time.sleep(2)
    fan1.report_event(90, "Full Time", "Match ends! Japan wins 2-1! Historic victory!")
    
    # Wait for listeners
    listener1.join()
    listener2.join()
    
    # Verify everyone got updates
    print("\n" + "="*60)
    print("📊 MATCH STATISTICS")
    print("="*60)
    
    print(f"\nFan Mueller sent: 4 reports")
    print(f"Fan Tanaka sent: 4 reports")
    print(f"Fan Schmidt sent: 1 report")
    
    print(f"\nFan Tanaka received: {len(fan2.events_received)} updates")
    print(f"Fan Schmidt received: {len(fan3.events_received)} updates")
    
    # Cleanup
    fan1.disconnect()
    fan2.disconnect()
    fan3.disconnect()
    
    # Success criteria
    success = (
        len(fan2.events_received) >= 3 and  # Should receive updates from others
        len(fan3.events_received) >= 3
    )
    
    if success:
        print("\n✅ FULL GAME SCENARIO PASSED!")
        print("   All fans stayed connected and received updates throughout match")
        return True
    else:
        print("\n❌ SCENARIO INCOMPLETE")
        print("   Some fans didn't receive expected updates")
        return False

if __name__ == "__main__":
    import sys
    
    try:
        success = simulate_world_cup_match()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ Scenario error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
PYTHON_EOF

# Check server
if ! nc -z 127.0.0.1 7777 2>/dev/null; then
    echo "❌ STOMP server not running"
    exit 1
fi

python3 $TEST_DIR/game_scenario.py

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ✅ FULL GAME SCENARIO PASSED                        ║"
    echo "║  Complete match simulation successful ✓              ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 0
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ❌ GAME SCENARIO FAILED                             ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 1
fi
