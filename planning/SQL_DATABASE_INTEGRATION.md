# SQL Database Integration - Implementation Plan

**Assignment 3 - Section 3.3: Database Integration**

---

## ⚠️ CRITICAL SAFETY REQUIREMENTS (READ FIRST)

Before implementation, these 3 technical groundings MUST be followed to prevent bugs:

### 1. **Logout Logic Safety (The "Leading Question")**
The logout UPDATE query must ONLY modify active sessions. Use:
```sql
UPDATE login_history 
SET logout_time = datetime('now') 
WHERE username = ? AND logout_time IS NULL
ORDER BY login_time DESC 
LIMIT 1
```
**Why:** Prevents accidentally modifying already-closed sessions or sessions from other connections.

### 2. **Python Socket Buffer Safety**
The Python server MUST use a **loop** to accumulate incoming data until the null terminator (`\0`) is detected. A single `recv(1024)` is NOT sufficient because TCP can fragment packets.

**Required Implementation:**
```python
def recv_null_terminated(sock):
    data = b""
    while True:
        chunk = sock.recv(1024)
        if not chunk:
            return ""  # Connection closed
        data += chunk
        if b"\0" in data:
            msg, _ = data.split(b"\0", 1)
            return msg.decode("utf-8", errors="replace")
```
**Why:** TCP does not guarantee message boundaries. A large SQL query may arrive in multiple packets.

### 3. **Java Thread Safety (Synchronized Socket Access)**
The `executeSQL()` method in `Database.java` MUST be `synchronized` to prevent race conditions when multiple threads send SQL commands simultaneously.

**Required:**
```java
private synchronized String executeSQL(String sql) {
    // ... socket communication code
}
```
**Why:** Our server uses TPC (Thread-Per-Client) or Reactor patterns. Without synchronization, multiple threads writing to the same socket will corrupt data.

---

## 1. OVERVIEW

### Objective
Move server state from in-memory data structures to an SQL database (SQLite) via a Python SQL server that receives SQL commands from the Java STOMP server.

### Architecture
```
┌─────────────────┐         Socket (TCP)          ┌──────────────────┐
│  Java STOMP     │    127.0.0.1:7778 \0-term     │  Python SQL      │
│  Server         │◄──────────────────────────────►│  Server          │
│  (Database.java)│    SQL String → Response       │  (sql_server.py) │
└─────────────────┘                                 └──────────────────┘
        │                                                   │
        │ executeSQL(sql)                                   │ execute(sql)
        ▼                                                   ▼
  In-memory state                                    ┌──────────────┐
  (ConcurrentHashMap)                                │   SQLite DB  │
  + SQL persistence                                  │stomp_server.db│
                                                     └──────────────┘
```

### Communication Protocol
- **Transport:** TCP Socket
- **Host:** `127.0.0.1`
- **Port:** `7778` (configurable)
- **Message Format:** Null-terminated strings (`\0`)
- **Connection Pattern:** Short-lived (new connection per SQL operation)

---

## 2. DATABASE SCHEMA DESIGN

### Table 1: `users`
**Purpose:** Track all registered users

```sql
CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT NOT NULL,
    registration_date TEXT NOT NULL
);
```

**Columns:**
- `username` (PK): Unique user identifier
- `password`: Plain-text password
- `registration_date`: SQLite datetime (`datetime('now')`)

**Operations:**
- INSERT: On new user registration (first login)
- SELECT: For report generation

---

### Table 2: `login_history`
**Purpose:** Track every login/logout session

```sql
CREATE TABLE IF NOT EXISTS login_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    login_time TEXT NOT NULL,
    logout_time TEXT,
    FOREIGN KEY (username) REFERENCES users(username)
);
```

**Columns:**
- `id` (PK): Unique session identifier (auto-increment)
- `username` (FK): Reference to users table
- `login_time`: When user logged in
- `logout_time`: When user logged out (`NULL` if still active)

**Operations:**
- INSERT: On every successful login (creates row with `logout_time = NULL`)
- UPDATE: On logout (updates most recent row where `logout_time IS NULL`)
- SELECT: For report generation

**Critical Logic - Logout Query:**

**⚠️ SAFETY REQUIREMENT #1: Only update active sessions**

```sql
UPDATE login_history 
SET logout_time = datetime('now') 
WHERE username = ? AND logout_time IS NULL
ORDER BY login_time DESC 
LIMIT 1
```

**Implementation Note:** SQLite doesn't support `ORDER BY` in `UPDATE` directly, so use subquery:

```sql
UPDATE login_history 
SET logout_time = datetime('now') 
WHERE id = (
    SELECT id FROM login_history 
    WHERE username = ? AND logout_time IS NULL 
    ORDER BY login_time DESC 
    LIMIT 1
)
```

**Why this is critical:**
- **Security:** Prevents updating wrong sessions if multiple logins exist
- **Correctness:** Only closes the currently active session (where `logout_time IS NULL`)
- **Edge cases handled:**
  - User logs in multiple times without logout → Updates only the latest
  - User already logged out → No rows match, no error thrown
  - No active session → Subquery returns NULL, UPDATE does nothing

**Java Implementation:**
```java
String sql = String.format(
    "UPDATE login_history SET logout_time=datetime('now') " +
    "WHERE id = (SELECT id FROM login_history " +
    "WHERE username='%s' AND logout_time IS NULL " +
    "ORDER BY login_time DESC LIMIT 1)",
    escapeSql(user.name)
);
executeSQL(sql);
```

---

### Table 3: `file_tracking`
**Purpose:** Log every file uploaded via `report` command

```sql
CREATE TABLE IF NOT EXISTS file_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    filename TEXT NOT NULL,
    upload_time TEXT NOT NULL,
    game_channel TEXT NOT NULL,
    FOREIGN KEY (username) REFERENCES users(username)
);
```

**Columns:**
- `id` (PK): Unique upload event identifier
- `username` (FK): Who uploaded the file
- `filename`: Path to JSON file (e.g., `./data/events1.json`)
- `upload_time`: When the file was reported
- `game_channel`: Game name (e.g., `Germany_Japan`)

**Operations:**
- INSERT: On every `report` command execution
- SELECT: For report generation

---

## 3. RESPONSE PROTOCOL

### For INSERT/UPDATE/DELETE Commands

**Success:**
```
SUCCESS
```

**Failure:**
```
ERROR:<error message>
```

### For SELECT Queries

**Success with rows:**
```
SUCCESS|('user1', '2026-01-20 10:30:00')|('user2', '2026-01-20 11:15:00')
```

**Success with no rows:**
```
SUCCESS
```

**Format:** Pipe-delimited string representations of tuples

---

## 4. PYTHON IMPLEMENTATION (`sql_server.py`)

### ⚠️ SAFETY REQUIREMENT #2: Buffer-Safe Socket Reading

**Critical Implementation:** The `recv_null_terminated()` function MUST use a loop to accumulate data until the delimiter is found. **Never** assume a single `recv(1024)` will contain the complete message.

### Step 0: Verify `recv_null_terminated()` is Buffer-Safe

**Existing skeleton code:**
```python
def recv_null_terminated(sock: socket.socket) -> str:
    data = b""
    while True:
        chunk = sock.recv(1024)
        if not chunk:
            return ""
        data += chunk
        if b"\0" in data:
            msg, _ = data.split(b"\0", 1)
            return msg.decode("utf-8", errors="replace")
```

**✅ This implementation is CORRECT** because:
1. Uses `while True` loop to keep reading
2. Accumulates chunks in `data` buffer
3. Only returns when `\0` delimiter is found
4. Handles connection close (`if not chunk`)

**❌ WRONG implementation (DO NOT USE):**
```python
# WRONG - Assumes entire message in one recv()
def recv_null_terminated_WRONG(sock):
    data = sock.recv(1024)  # DANGEROUS!
    return data.decode('utf-8').rstrip('\0')
```

**Why TCP fragmentation matters:**
- SQL query > 1024 bytes → Split across multiple packets
- Network latency → Packets arrive separately
- OS buffering → Arbitrary chunk sizes

### Step 1: Add SQLite Import
```python
import sqlite3
```

### Step 2: Implement `init_database()`

```python
def init_database():
    """Initialize SQLite database with required tables"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    # Create users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            username TEXT PRIMARY KEY,
            password TEXT NOT NULL,
            registration_date TEXT NOT NULL
        )
    ''')
    
    # Create login_history table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS login_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            login_time TEXT NOT NULL,
            logout_time TEXT,
            FOREIGN KEY (username) REFERENCES users(username)
        )
    ''')
    
    # Create file_tracking table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS file_tracking (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            filename TEXT NOT NULL,
            upload_time TEXT NOT NULL,
            game_channel TEXT NOT NULL,
            FOREIGN KEY (username) REFERENCES users(username)
        )
    ''')
    
    conn.commit()
    conn.close()
```

### Step 3: Implement `execute_sql_command()`

```python
def execute_sql_command(sql_command: str) -> str:
    """Execute INSERT/UPDATE/DELETE commands"""
    try:
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        cursor.execute(sql_command)
        conn.commit()
        conn.close()
        return "SUCCESS"
    except Exception as e:
        return f"ERROR:{str(e)}"
```

### Step 4: Implement `execute_sql_query()`

```python
def execute_sql_query(sql_query: str) -> str:
    """Execute SELECT queries and return results"""
    try:
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        cursor.execute(sql_query)
        rows = cursor.fetchall()
        conn.close()
        
        if len(rows) == 0:
            return "SUCCESS"
        
        # Format: SUCCESS|row1|row2|...
        row_strings = [str(row) for row in rows]
        return "SUCCESS|" + "|".join(row_strings)
    except Exception as e:
        return f"ERROR:{str(e)}"
```

### Step 5: Update `handle_client()`

```python
def handle_client(client_socket: socket.socket, addr):
    print(f"[{SERVER_NAME}] Client connected from {addr}")

    try:
        while True:
            message = recv_null_terminated(client_socket)
            if message == "":
                break

            print(f"[{SERVER_NAME}] Received SQL:")
            print(message)

            # Route based on SQL command type
            sql_upper = message.strip().upper()
            if sql_upper.startswith("SELECT"):
                response = execute_sql_query(message)
            else:
                response = execute_sql_command(message)
            
            print(f"[{SERVER_NAME}] Response: {response[:100]}...")  # Truncate long responses
            
            # Send response with null terminator
            client_socket.sendall(response.encode('utf-8') + b'\0')

    except Exception as e:
        print(f"[{SERVER_NAME}] Error handling client {addr}: {e}")
        error_response = f"ERROR:{str(e)}"
        try:
            client_socket.sendall(error_response.encode('utf-8') + b'\0')
        except:
            pass
    finally:
        try:
            client_socket.close()
        except Exception:
            pass
        print(f"[{SERVER_NAME}] Client {addr} disconnected")
```

### Step 6: Update `start_server()`

```python
def start_server(host="127.0.0.1", port=7778):
    # Initialize database on startup
    print(f"[{SERVER_NAME}] Initializing database...")
    init_database()
    print(f"[{SERVER_NAME}] Database initialized successfully")
    
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    # ... rest of existing code
```

---

## 5. JAVA IMPLEMENTATION

### ⚠️ SAFETY REQUIREMENT #3: Thread-Safe Socket Access

**Critical:** The `executeSQL()` method MUST be `synchronized` because our server is multi-threaded (TPC/Reactor). Without synchronization, concurrent SQL operations will corrupt socket I/O.

### Current Implementation Status

The Java side is **mostly implemented** in `Database.java`:

✅ **Socket Communication:**
```java
private synchronized String executeSQL(String sql) {  // ← MUST BE synchronized!
    try (Socket socket = new Socket(sqlHost, sqlPort);
         PrintWriter out = new PrintWriter(socket.getOutputStream(), true);
         BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()))) {
        
        // Send SQL with null terminator
        out.print(sql + '\0');
        out.flush();
        
        // Read response until null terminator
        StringBuilder response = new StringBuilder();
        int ch;
        while ((ch = in.read()) != -1 && ch != '\0') {
            response.append((char) ch);
        }
        
        return response.toString();
        
    } catch (Exception e) {
        System.err.println("SQL Error: " + e.getMessage());
        return "ERROR:" + e.getMessage();
    }
}
```

**Why synchronization is critical:**
- **TPC Mode:** Each client has its own thread calling `login()`, `logout()`, etc.
- **Race Condition:** Without `synchronized`, Thread A and Thread B can both enter `executeSQL()` simultaneously
- **Socket Corruption:** Both threads write to different sockets (OK), but if we ever reuse a connection pool, data gets interleaved
- **Even with new socket per call:** Prevents resource exhaustion from too many simultaneous connections

**Alternative (if avoiding synchronized):**
Use a connection pool with `synchronized` access or a `Semaphore` to limit concurrent connections. However, for this assignment, `synchronized` is the simplest and correct solution.

### Existing Java Code Review

✅ **SQL Calls in Business Logic:**
- `login()` - Inserts user registration and login
- `logout()` - Updates logout timestamp (verify query matches SAFETY REQUIREMENT #1)
- `trackFileUpload()` - Inserts file tracking record

✅ **Report Generation:**
- `printReport()` - Queries all three tables and formats output

✅ **SQL Injection Prevention:**
- `escapeSql()` method escapes single quotes: `'` → `''`

### Missing Integration Point ⚠️

**Need to call `trackFileUpload()` in STOMP protocol:**

File: `StompMessagingProtocolImpl.java`

In the method that handles the `report` command (when processing events from JSON file):

```java
// After successfully parsing events from file
String filename = extractedFilename;  // e.g., "./data/events1.json"
String gameChannel = gameName;        // e.g., "Germany_Japan"
String username = currentUser.name;

// Track in SQL database
Database.getInstance().trackFileUpload(username, filename, gameChannel);
```

**Where to add:**
Look for where `parseEventsFile()` or similar is called in the STOMP message handling for the `report` command.

---

## 6. TESTING STRATEGY

### Phase 1: Python SQL Server Tests

**Start the Python server:**
```bash
cd /workspaces/Assignment\ 3\ SPL/data
python3 sql_server.py 7778
```

**Test with netcat:**
```bash
# Test 1: Create user
echo "INSERT INTO users (username, password, registration_date) VALUES ('testuser', 'pass123', datetime('now'))" | nc 127.0.0.1 7778

# Test 2: Select users
echo "SELECT * FROM users" | nc 127.0.0.1 7778

# Test 3: Login
echo "INSERT INTO login_history (username, login_time) VALUES ('testuser', datetime('now'))" | nc 127.0.0.1 7778

# Test 4: Logout
echo "UPDATE login_history SET logout_time=datetime('now') WHERE username='testuser' AND logout_time IS NULL ORDER BY login_time DESC LIMIT 1" | nc 127.0.0.1 7778

# Test 5: Select login history
echo "SELECT * FROM login_history" | nc 127.0.0.1 7778
```

**Expected Results:**
- All commands should return `SUCCESS`
- SELECT queries should return data in format: `SUCCESS|(...)|(...)`

### Phase 2: Java Integration Tests

**Prerequisites:**
1. Start Python SQL server (port 7778)
2. Start Java STOMP server (port 7777)

**Test Scenario:**
```
Client 1: login 127.0.0.1:7777 alice pass1
Client 1: join Germany_Japan
Client 1: report ./data/events1.json
Client 1: logout

Client 2: login 127.0.0.1:7777 bob pass2
Client 2: join Germany_Japan
Client 2: logout
```

**Verification:**
Check the SQLite database directly:
```bash
sqlite3 /workspaces/Assignment\ 3\ SPL/data/stomp_server.db

sqlite> SELECT * FROM users;
sqlite> SELECT * FROM login_history;
sqlite> SELECT * FROM file_tracking;
sqlite> .quit
```

### Phase 3: Report Function Test

**Add report trigger to server:**

Option A: Server console command
- Add keyboard input reader in server main thread
- When user types "report", call `Database.getInstance().printReport()`

Option B: Scheduled task
- Add timer that calls `printReport()` every 5 minutes

Option C: Shutdown hook
- Add shutdown hook that prints report on server exit:
```java
Runtime.getRuntime().addShutdownHook(new Thread(() -> {
    System.out.println("\n=== SERVER SHUTDOWN - FINAL REPORT ===");
    Database.getInstance().printReport();
}));
```

**Expected Report Output:**
```
================================================================================
SERVER REPORT - Generated at: 2026-01-20T15:30:45.123
================================================================================

1. REGISTERED USERS:
--------------------------------------------------------------------------------
   ('alice', '2026-01-20 15:25:10')
   ('bob', '2026-01-20 15:28:30')

2. LOGIN HISTORY:
--------------------------------------------------------------------------------

   User: alice
      Login:  2026-01-20 15:25:10
      Logout: 2026-01-20 15:27:15

   User: bob
      Login:  2026-01-20 15:28:30
      Logout: 2026-01-20 15:29:45

3. FILE UPLOADS:
--------------------------------------------------------------------------------

   User: alice
      File: ./data/events1.json
      Time: 2026-01-20 15:26:00
      Game: Germany_Japan

================================================================================
```

---

## 7. IMPLEMENTATION CHECKLIST

### Python SQL Server (`sql_server.py`)
- [x] Verify `recv_null_terminated()` uses loop (SAFETY REQUIREMENT #2) ✅
- [ ] Add `import sqlite3` at top
- [ ] Implement `init_database()` with 3 CREATE TABLE statements
- [ ] Implement `execute_sql_command()` for INSERT/UPDATE/DELETE
- [ ] Implement `execute_sql_query()` for SELECT
- [ ] Update `handle_client()` to route commands vs queries
- [ ] Update `start_server()` to call `init_database()` on startup
- [ ] Test with netcat (manual SQL commands)

### Java STOMP Server
- [ ] **CRITICAL:** Verify `executeSQL()` is `synchronized` (SAFETY REQUIREMENT #3)
- [ ] **CRITICAL:** Verify logout query uses subquery (SAFETY REQUIREMENT #1)
- [ ] Find where `report` command processes JSON file in `StompMessagingProtocolImpl.java`
- [ ] Add call to `Database.getInstance().trackFileUpload(username, filename, gameChannel)`
- [ ] Test that file tracking records are created

### Report Function (Choose one)
- [ ] Option A: Server console command
- [ ] Option B: Scheduled task
- [ ] Option C: Shutdown hook (recommended for testing)

### Integration Testing
- [ ] Start Python SQL server on port 7778
- [ ] Start Java STOMP server on port 7777
- [ ] Run full client scenario (login, report, logout)
- [ ] Verify SQLite database has correct data
- [ ] Trigger report function and verify output

### Safety Verification (MANDATORY)
- [ ] **Test SAFETY #1:** Multiple logins from same user → Logout only closes latest
- [ ] **Test SAFETY #2:** Send large SQL query (>2KB) → Received correctly
- [ ] **Test SAFETY #3:** 10 concurrent clients login simultaneously → No data corruption

---

## 8. EDGE CASES TO HANDLE

### SQL Injection Prevention
✅ Already handled in Java with `escapeSql()` method
- Escapes single quotes: `'` → `''`

### Concurrent Access
✅ SQLite handles locking automatically
- Multiple connections work correctly
- Python server uses thread-per-client model

### Database File Location
⚠️ Verify `stomp_server.db` is created in correct directory:
- Should be in `/workspaces/Assignment 3 SPL/data/`
- Check with: `ls -la /workspaces/Assignment\ 3\ SPL/data/stomp_server.db`

### Logout with No Active Session
✅ UPDATE query handles this correctly:
- If no rows match `WHERE logout_time IS NULL`, nothing happens
- No error thrown

### Multiple Concurrent Logins (Same User)
✅ Each login creates separate row with unique `id`
- Logout updates only the most recent one
- Login history preserves all sessions

---

## 9. DEBUGGING TIPS

### Python SQL Server Not Responding
```bash
# Check if server is running
ps aux | grep sql_server.py

# Check if port is in use
lsof -i :7778

# Test connectivity
telnet 127.0.0.1 7778
```

### Java Cannot Connect to SQL Server
```java
// Add debug prints in executeSQL()
System.out.println("Connecting to SQL server at " + sqlHost + ":" + sqlPort);
System.out.println("Sending SQL: " + sql);
System.out.println("Received response: " + response);
```

### SQLite Database Locked
```bash
# Check for other connections
fuser /workspaces/Assignment\ 3\ SPL/data/stomp_server.db

# If stuck, kill and restart
killall python3
```

### Query Returns Unexpected Format
- Print raw response in Java before parsing
- Check Python `str(row)` output matches expected format
- Test with simple SELECT first (e.g., `SELECT 1`)

---

## 10. COMPLETION CRITERIA

✅ **Python SQL Server:**
- Creates SQLite database on startup
- Accepts SQL commands via socket
- Returns proper response format
- Handles both commands and queries

✅ **Java Integration:**
- All user registrations logged to `users` table
- All logins/logouts logged to `login_history` table
- All file uploads logged to `file_tracking` table

✅ **Report Function:**
- Prints all registered users
- Prints login/logout history per user
- Prints file uploads per user
- Uses ONLY SQL queries (no in-memory scanning)

✅ **Testing:**
- Manual SQL tests with netcat work
- Full STOMP client scenario creates DB records
- Report shows correct data from SQL

---

## 11. FINAL NOTES

### Assignment Requirements Met
✅ Move server state to SQL database  
✅ Python SQL server executes SQL operations  
✅ Database schema follows relational design principles  
✅ Tracks: user registration, login timestamps, logout timestamps, file uploads  
✅ Report function uses SQL queries only  

### What's NOT Required
- Authentication between Java and Python servers
- Encryption of SQL commands
- Complex SQL optimizations (indexes, etc.)
- Database backup/restore functionality

### Submission Checklist
- [ ] `sql_server.py` fully implemented
- [ ] Java code calls `trackFileUpload()` in report command
- [ ] Report function implemented and tested
- [ ] README updated with instructions to start SQL server
- [ ] Test scenario documented
- [ ] SQLite database file NOT committed to git (add to .gitignore)

---

**END OF IMPLEMENTATION PLAN**
