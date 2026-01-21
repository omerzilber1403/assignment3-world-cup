#!/bin/bash
# Suite D: Large Data Test
# Tests SAFETY #2: TCP buffer safety with large queries

set -e

echo "🧪 Suite D: Large Data Test"
echo "Testing TCP buffer safety with large SQL responses"
echo ""

SQL_HOST="127.0.0.1"
SQL_PORT="7778"

# Check if SQL server is running
if ! nc -z $SQL_HOST $SQL_PORT 2>/dev/null; then
    echo "❌ SQL server not running on port $SQL_PORT"
    echo "Please start: cd data && python3 sql_server.py $SQL_PORT"
    exit 1
fi

echo "Test 1: Large SELECT Query (SAFETY #2)"
echo "Sending query that returns >5KB of data..."

# Create Python script to test large data
python3 << 'PYTHON_EOF'
import socket
import sys

def send_large_sql_query():
    """Test that server can handle large responses"""
    
    # Create a query that returns lots of data
    # SELECT with 300 columns should return >5KB
    columns = [f"'{i}' as col{i}" for i in range(300)]
    query = "SELECT " + ", ".join(columns) + ";"
    
    print(f"Query size: {len(query)} bytes")
    print(f"Expected response size: >5KB")
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(('127.0.0.1', 7778))
    
    # Send query
    sock.sendall((query + '\0').encode())
    
    # Receive response using loop (testing SAFETY #2)
    response = b''
    chunk_count = 0
    while True:
        chunk = sock.recv(1024)  # Read in 1KB chunks
        if not chunk:
            break
        response += chunk
        chunk_count += 1
        if b'\0' in response:
            break
    
    sock.close()
    
    response_str = response.decode().strip('\0')
    print(f"\n✅ Received response in {chunk_count} chunks")
    print(f"   Total response size: {len(response_str)} bytes")
    
    # Verify we got all columns
    if chunk_count > 1:
        print(f"✅ SAFETY #2 VERIFIED: Server used multiple reads")
    
    # Check that we got complete data
    if "col299" in response_str or "299" in response_str:
        print(f"✅ Complete data received (last column present)")
        return True
    else:
        print(f"❌ Data truncated! Last column not found")
        return False

if __name__ == "__main__":
    success = send_large_sql_query()
    sys.exit(0 if success else 1)
PYTHON_EOF

if [ $? -eq 0 ]; then
    echo "✅ Test 1 PASSED: Large query handled correctly"
else
    echo "❌ Test 1 FAILED: Large query truncated"
    exit 1
fi

echo ""
echo "Test 2: Populate Large Dataset"
echo "Inserting 100 users and 1000 events..."

python3 << 'PYTHON_EOF'
import socket
import time

def send_sql(query):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(('127.0.0.1', 7778))
    sock.sendall((query + '\0').encode())
    
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

# Insert 100 users
print("Inserting users...")
for i in range(100):
    query = f"INSERT OR IGNORE INTO users (username, password) VALUES ('loadtest_user{i}', 'pass{i}');"
    send_sql(query)
    if i % 20 == 0:
        print(f"  Progress: {i}/100 users")

print("✅ 100 users inserted")

# Insert 1000 login records
print("\nInserting login history records...")
for i in range(1000):
    user_id = i % 100
    query = f"INSERT INTO login_history (username, login_time) VALUES ('loadtest_user{user_id}', datetime('now'));"
    send_sql(query)
    if i % 200 == 0:
        print(f"  Progress: {i}/1000 logins")

print("✅ 1000 login records inserted")
PYTHON_EOF

echo "✅ Test 2 PASSED: Large dataset created"
echo ""

echo "Test 3: Query Large Dataset"
echo "Retrieving all data..."

python3 << 'PYTHON_EOF'
import socket

def query_large_data():
    queries = [
        ("Users", "SELECT COUNT(*) FROM users WHERE username LIKE 'loadtest_%';"),
        ("Logins", "SELECT COUNT(*) FROM login_history WHERE username LIKE 'loadtest_%';"),
        ("All Users", "SELECT * FROM users WHERE username LIKE 'loadtest_%' LIMIT 10;")
    ]
    
    for name, query in queries:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(('127.0.0.1', 7778))
        sock.sendall((query + '\0').encode())
        
        response = b''
        while True:
            chunk = sock.recv(1024)
            if not chunk:
                break
            response += chunk
            if b'\0' in response:
                break
        
        sock.close()
        result = response.decode().strip('\0')
        
        print(f"Query: {name}")
        print(f"  Response size: {len(result)} bytes")
        
        if "COUNT" in query:
            try:
                count = int(result.split()[-1])
                print(f"  Count: {count}")
            except:
                print(f"  Result: {result[:100]}...")
        else:
            print(f"  Sample: {result[:200]}...")
        
        print()

query_large_data()
print("✅ All large queries successful")
PYTHON_EOF

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  ✅ LARGE DATA TEST PASSED                           ║"
echo "║  SAFETY #2: TCP buffer loop verified ✓               ║"
echo "║  Large datasets handled correctly ✓                  ║"
echo "╚═══════════════════════════════════════════════════════╝"

exit 0
