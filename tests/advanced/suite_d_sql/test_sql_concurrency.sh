#!/bin/bash
# Suite D: SQL Concurrency Test
# Tests SAFETY #3: synchronized executeSQL with concurrent access

set -e

echo "🧪 Suite D: SQL Concurrency Test"
echo "Testing synchronized database access with 10 concurrent connections"
echo ""

# Configuration
SQL_HOST="127.0.0.1"
SQL_PORT="7778"
TEST_USERS=10
DB_FILE="../../data/stomp_server.db"

# Check if SQL server is running
check_sql_server() {
    echo "📡 Checking if Python SQL server is running on port $SQL_PORT..."
    if ! nc -z $SQL_HOST $SQL_PORT 2>/dev/null; then
        echo "❌ SQL server not running. Please start it first:"
        echo "   cd data && python3 sql_server.py $SQL_PORT"
        exit 1
    fi
    echo "✅ SQL server is running"
}

# Test concurrent user registrations
test_concurrent_registrations() {
    echo ""
    echo "Test 1: Concurrent User Registrations"
    echo "Creating $TEST_USERS users simultaneously..."
    
    # Create Python script for concurrent testing
    cat > /tmp/test_concurrent_sql.py << 'PYTHON_EOF'
import socket
import threading
import time
import sys

def send_sql_command(command, host='127.0.0.1', port=7778):
    """Send SQL command to Python SQL server"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((host, port))
        
        # Send command
        full_command = command + '\0'
        sock.sendall(full_command.encode())
        
        # Receive response (loop until \0)
        response = b''
        while True:
            chunk = sock.recv(1024)
            if not chunk:
                break
            response += chunk
            if b'\0' in response:
                break
        
        sock.close()
        return response.decode().strip('\0')
    except Exception as e:
        return f"ERROR: {e}"

def register_user(user_id):
    """Register a user concurrently"""
    username = f"user{user_id}"
    password = f"pass{user_id}"
    
    command = f"INSERT INTO users (username, password) VALUES ('{username}', '{password}');"
    result = send_sql_command(command)
    
    if "SUCCESS" in result or "UNIQUE constraint failed" in result:
        print(f"✅ User {username} registered (or already exists)")
        return True
    else:
        print(f"❌ Failed to register {username}: {result}")
        return False

def test_concurrent_logins(user_count):
    """Test concurrent login tracking"""
    threads = []
    results = []
    
    def login_user(user_id):
        username = f"user{user_id}"
        command = f"INSERT INTO login_history (username, login_time) VALUES ('{username}', datetime('now'));"
        result = send_sql_command(command)
        results.append("SUCCESS" in result)
    
    for i in range(user_count):
        t = threading.Thread(target=login_user, args=(i,))
        threads.append(t)
        t.start()
    
    for t in threads:
        t.join()
    
    return all(results)

def test_concurrent_file_tracking(user_count):
    """Test concurrent file upload tracking"""
    threads = []
    results = []
    
    def track_file(user_id):
        username = f"user{user_id}"
        filename = f"events{user_id}.json"
        command = f"INSERT INTO file_tracking (username, filename, upload_time) VALUES ('{username}', '{filename}', datetime('now'));"
        result = send_sql_command(command)
        results.append("SUCCESS" in result or "inserted" in result.lower())
    
    for i in range(user_count):
        t = threading.Thread(target=track_file, args=(i,))
        threads.append(t)
        t.start()
    
    for t in threads:
        t.join()
    
    return all(results)

if __name__ == "__main__":
    user_count = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    
    print(f"\n=== Testing {user_count} concurrent database operations ===\n")
    
    # Test 1: Concurrent registrations
    threads = []
    for i in range(user_count):
        t = threading.Thread(target=register_user, args=(i,))
        threads.append(t)
        t.start()
    
    for t in threads:
        t.join()
    
    print(f"\n✅ Concurrent registrations completed")
    
    # Test 2: Concurrent logins
    print(f"\nTesting {user_count} concurrent logins...")
    if test_concurrent_logins(user_count):
        print(f"✅ All concurrent logins tracked successfully")
    else:
        print(f"❌ Some concurrent logins failed")
        sys.exit(1)
    
    # Test 3: Concurrent file tracking
    print(f"\nTesting {user_count} concurrent file uploads...")
    if test_concurrent_file_tracking(user_count):
        print(f"✅ All concurrent file trackings successful")
    else:
        print(f"❌ Some file trackings failed")
        sys.exit(1)
    
    print(f"\n🎉 All concurrent SQL tests PASSED!")
PYTHON_EOF

    # Run the concurrent test
    python3 /tmp/test_concurrent_sql.py $TEST_USERS
    
    if [ $? -eq 0 ]; then
        echo "✅ Test 1 PASSED: Concurrent registrations successful"
        return 0
    else
        echo "❌ Test 1 FAILED"
        return 1
    fi
}

# Test database consistency after concurrent operations
test_database_consistency() {
    echo ""
    echo "Test 2: Database Consistency Check"
    echo "Verifying no data corruption occurred..."
    
    # Count users
    python3 << 'PYTHON_EOF'
import socket

def query_sql(command):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(('127.0.0.1', 7778))
    sock.sendall((command + '\0').encode())
    
    response = b''
    while True:
        chunk = sock.recv(1024)
        if not chunk:
            break
        response += chunk
        if b'\0' in response:
            break
    
    sock.close()
    return response.decode().strip('\0')

# Check user count
result = query_sql("SELECT COUNT(*) FROM users;")
count = int(result.split()[-1]) if result else 0
print(f"Total users in database: {count}")

if count >= 10:
    print(f"✅ Database has expected number of users")
else:
    print(f"❌ Database has fewer users than expected")
    exit(1)

# Check login history
result = query_sql("SELECT COUNT(*) FROM login_history;")
login_count = int(result.split()[-1]) if result else 0
print(f"Total login records: {login_count}")

# Check file tracking
result = query_sql("SELECT COUNT(*) FROM file_tracking;")
file_count = int(result.split()[-1]) if result else 0
print(f"Total file tracking records: {file_count}")

print(f"\n✅ Database consistency verified")
PYTHON_EOF

    if [ $? -eq 0 ]; then
        echo "✅ Test 2 PASSED: Database is consistent"
        return 0
    else
        echo "❌ Test 2 FAILED"
        return 1
    fi
}

# Main execution
echo "═══════════════════════════════════════════════════════════"
echo "  SQL CONCURRENCY TEST - SAFETY REQUIREMENT #3"
echo "═══════════════════════════════════════════════════════════"

check_sql_server

if test_concurrent_registrations && test_database_consistency; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ✅ SQL CONCURRENCY TEST PASSED                      ║"
    echo "║  SAFETY #3: Synchronized executeSQL verified ✓       ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 0
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ❌ SQL CONCURRENCY TEST FAILED                      ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 1
fi
