#!/bin/bash
# Suite D: SQL Persistence Test
# Tests database persistence across server restarts

set -e

echo "🧪 Suite D: SQL Persistence Test"
echo "Testing data persistence across server restarts"
echo ""

DB_FILE="../../data/stomp_server.db"
SQL_HOST="127.0.0.1"
SQL_PORT="7778"

# Helper function to send SQL command
send_sql() {
    python3 << PYTHON_EOF
import socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    sock.connect(('$SQL_HOST', $SQL_PORT))
    sock.sendall(('$1' + '\0').encode())
    response = b''
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            break
        response += chunk
        if b'\0' in response:
            break
    print(response.decode().strip('\0'))
finally:
    sock.close()
PYTHON_EOF
}

echo "Test 1: Insert Test Data"
echo "Inserting known data into database..."

# Check if SQL server is running
if ! nc -z $SQL_HOST $SQL_PORT 2>/dev/null; then
    echo "❌ SQL server not running on port $SQL_PORT"
    exit 1
fi

# Insert test users
send_sql "INSERT OR IGNORE INTO users (username, password) VALUES ('persistence_test_user1', 'testpass1');"
send_sql "INSERT OR IGNORE INTO users (username, password) VALUES ('persistence_test_user2', 'testpass2');"

# Insert login history
send_sql "INSERT INTO login_history (username, login_time) VALUES ('persistence_test_user1', datetime('now'));"
send_sql "INSERT INTO login_history (username, login_time) VALUES ('persistence_test_user2', datetime('now'));"

# Insert file tracking
send_sql "INSERT INTO file_tracking (username, filename, upload_time) VALUES ('persistence_test_user1', 'test_events.json', datetime('now'));"

echo "✅ Test data inserted"
echo ""

echo "Test 2: Verify Data Before Restart"
result=$(send_sql "SELECT COUNT(*) FROM users WHERE username LIKE 'persistence_test_%';")
count=$(echo "$result" | grep -o '[0-9]*' | tail -1)

if [ "$count" -ge "2" ]; then
    echo "✅ Found $count test users in database"
else
    echo "❌ Expected 2 test users, found $count"
    exit 1
fi

echo ""
echo "⚠️  Manual Step Required:"
echo "    Please restart the Python SQL server and STOMP server,"
echo "    then press ENTER to continue testing persistence..."
read -p "Press ENTER after restarting servers: "

echo ""
echo "Test 3: Verify Data After Restart"

# Give servers time to start
sleep 2

# Check if SQL server is back up
if ! nc -z $SQL_HOST $SQL_PORT 2>/dev/null; then
    echo "❌ SQL server not running after restart"
    exit 1
fi

# Query the same data
result=$(send_sql "SELECT COUNT(*) FROM users WHERE username LIKE 'persistence_test_%';")
count_after=$(echo "$result" | grep -o '[0-9]*' | tail -1)

if [ "$count_after" -ge "2" ]; then
    echo "✅ Data persisted! Found $count_after test users after restart"
else
    echo "❌ Data lost! Expected 2 test users, found $count_after"
    exit 1
fi

# Check login history
result=$(send_sql "SELECT COUNT(*) FROM login_history WHERE username LIKE 'persistence_test_%';")
login_count=$(echo "$result" | grep -o '[0-9]*' | tail -1)

if [ "$login_count" -ge "2" ]; then
    echo "✅ Login history persisted! Found $login_count records"
else
    echo "❌ Login history lost!"
    exit 1
fi

# Check file tracking
result=$(send_sql "SELECT COUNT(*) FROM file_tracking WHERE username LIKE 'persistence_test_%';")
file_count=$(echo "$result" | grep -o '[0-9]*' | tail -1)

if [ "$file_count" -ge "1" ]; then
    echo "✅ File tracking persisted! Found $file_count records"
else
    echo "❌ File tracking lost!"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  ✅ SQL PERSISTENCE TEST PASSED                      ║"
echo "║  All data survived server restart ✓                  ║"
echo "╚═══════════════════════════════════════════════════════╝"

exit 0
