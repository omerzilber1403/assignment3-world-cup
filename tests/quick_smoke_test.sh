#!/bin/bash
# Quick Smoke Test - 30 seconds validation
# Tests basic functionality without deep validation

set -e  # Exit on error

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🔥 QUICK SMOKE TEST - Assignment 3 SPL                   ║"
echo "║  Duration: ~30 seconds                                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

WORKSPACE="/workspaces/Assignment 3 SPL"
cd "$WORKSPACE"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
pkill -f "sql_server.py" 2>/dev/null || true
pkill -f "StompServer" 2>/dev/null || true
pkill -f "StompWCIClient" 2>/dev/null || true
rm -f data/stomp_server.db
rm -f /tmp/test_*.log
pass "Cleanup completed"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Compilation Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Client
cd "$WORKSPACE/client"
if make clean && make StompWCIClient > /tmp/test_client_compile.log 2>&1; then
    pass "Client compiled"
else
    fail "Client compilation failed (see /tmp/test_client_compile.log)"
fi

# Server
cd "$WORKSPACE/server"
if mvn clean compile > /tmp/test_server_compile.log 2>&1; then
    pass "Server compiled"
else
    fail "Server compilation failed (see /tmp/test_server_compile.log)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Start Python SQL Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$WORKSPACE/data"
python3 sql_server.py 7778 > /tmp/test_sql_server.log 2>&1 &
SQL_PID=$!
sleep 2

if ps -p $SQL_PID > /dev/null; then
    pass "Python SQL Server started (PID: $SQL_PID)"
else
    fail "Python SQL Server failed to start"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Test SQL Server Direct"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

python3 << 'EOF'
import socket
sock = socket.socket()
sock.connect(('127.0.0.1', 7778))
sock.sendall(b"INSERT INTO users (username, password, registration_date) VALUES ('smoketest', 'pass', datetime('now'))\0")
response = b''
while True:
    chunk = sock.recv(1024)
    response += chunk
    if b'\0' in response:
        break
sock.close()
if b'SUCCESS' in response:
    print("✅ SQL Server responding correctly")
    exit(0)
else:
    print("❌ SQL Server returned unexpected response:", response)
    exit(1)
EOF

if [ $? -eq 0 ]; then
    pass "SQL Server operational"
else
    fail "SQL Server not responding correctly"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Start Java STOMP Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$WORKSPACE/server"
mvn exec:java -Dexec.mainClass="bgu.spl.net.impl.stomp.StompServer" -Dexec.args="7777 tpc" > /tmp/test_stomp_server.log 2>&1 &
STOMP_PID=$!
sleep 5

if ps -p $STOMP_PID > /dev/null; then
    pass "Java STOMP Server started (PID: $STOMP_PID)"
else
    fail "Java STOMP Server failed to start"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Test STOMP Server Connection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

python3 << 'EOF'
import socket
import time

try:
    sock = socket.socket()
    sock.settimeout(5)
    sock.connect(('127.0.0.1', 7777))
    
    # Send CONNECT frame
    connect = "CONNECT\nlogin:smoketest\npasscode:pass\n\n\0"
    sock.sendall(connect.encode())
    
    # Wait for CONNECTED response
    response = b''
    while True:
        chunk = sock.recv(1024)
        response += chunk
        if b'\0' in response:
            break
    
    sock.close()
    
    if b'CONNECTED' in response:
        print("✅ STOMP Server accepting connections")
        exit(0)
    else:
        print("❌ Unexpected response:", response)
        exit(1)
        
except Exception as e:
    print(f"❌ Connection failed: {e}")
    exit(1)
EOF

if [ $? -eq 0 ]; then
    pass "STOMP Server operational"
else
    fail "STOMP Server not responding correctly"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Database Integration Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$WORKSPACE/data"
python3 << 'EOF'
import sqlite3
import sys

try:
    conn = sqlite3.connect('stomp_server.db')
    cursor = conn.cursor()
    
    # Check tables exist
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cursor.fetchall()]
    
    required = ['users', 'login_history', 'file_tracking']
    missing = [t for t in required if t not in tables]
    
    if missing:
        print(f"❌ Missing tables: {missing}")
        sys.exit(1)
    
    # Check users table has data
    cursor.execute("SELECT COUNT(*) FROM users")
    count = cursor.fetchone()[0]
    
    if count > 0:
        print(f"✅ Database has {count} users")
        sys.exit(0)
    else:
        print("⚠️  Database empty (expected after CONNECT)")
        sys.exit(0)
    
except Exception as e:
    print(f"❌ Database error: {e}")
    sys.exit(1)
finally:
    conn.close()
EOF

if [ $? -eq 0 ]; then
    pass "Database integration working"
else
    fail "Database integration failed"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

kill $SQL_PID 2>/dev/null || true
kill $STOMP_PID 2>/dev/null || true
sleep 1
pass "Servers stopped"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ SMOKE TEST PASSED - All basic functionality works     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Logs available in /tmp/test_*.log"
echo "Next: Run ./tests/sql_integration_test.sh for detailed SQL tests"
