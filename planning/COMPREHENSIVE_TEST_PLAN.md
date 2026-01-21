# 🧪 Comprehensive Testing Plan - Assignment 3 SPL

**Generated:** January 20, 2026  
**Purpose:** Complete testing strategy to validate all assignment requirements (Sections 3.1, 3.2, 3.3)

---

## 📋 ASSIGNMENT REQUIREMENTS SUMMARY

### Section 3.1: STOMP Client (C++)
✅ Implemented with thread-safe design
- Multi-threaded keyboard + socket reader
- Mutex-protected shared state
- Commands: login, join, exit, report, summary, logout

### Section 3.2: STOMP Server (Java)
✅ Implemented with TPC + Reactor patterns
- Connections interface
- Thread-per-client (TPC) server
- Reactor server
- STOMP protocol handling

### Section 3.3: SQL Database Integration (NEW)
✅ Just implemented
- Python SQL server on port 7778
- SQLite database (stomp_server.db)
- 3 tables: users, login_history, file_tracking
- Java server communicates with SQL server

---

## 🎯 TEST LEVELS

### Level 1: Unit Tests (Client)
**Files:** `tests/test_frame_format.cpp`, `tests/test_event_parsing.cpp`  
**Status:** ✅ Already created
**Run:** `cd tests && make test`

### Level 2: Server Unit Tests
**What to test:**
- Frame parsing
- Protocol command handling
- Database operations

### Level 3: Integration Tests
**What to test:**
- Client ↔ Server communication
- Multiple concurrent clients
- Full workflow scenarios

### Level 4: SQL Integration Tests
**What to test:**
- Java ↔ Python SQL server communication
- Database persistence
- Login/logout tracking
- File upload tracking

### Level 5: Stress Tests
**What to test:**
- 10+ concurrent clients
- Large file uploads
- Long-running sessions
- Error recovery

---

## 🔥 CRITICAL TEST SCENARIOS (MUST PASS)

### Scenario 1: Basic Workflow ⭐⭐⭐
**Client 1 (messi):**
1. login 127.0.0.1:7777 messi pass123
2. join Germany_Japan
3. report ./data/events1.json
4. logout

**Expected:**
- ✅ Connection successful
- ✅ Joined channel
- ✅ All events sent
- ✅ Database has login/logout times
- ✅ Database has file tracking records

---

### Scenario 2: Two Clients Exchange Messages ⭐⭐⭐
**Client 1 (messi):**
1. login 127.0.0.1:7777 messi pass123
2. join Germany_Japan
3. report ./data/events1.json

**Client 2 (ronaldo):**
1. login 127.0.0.1:7777 ronaldo pass456
2. join Germany_Japan
3. (should receive all events from messi)
4. summary Germany_Japan messi ronaldo
5. logout

**Expected:**
- ✅ Both clients connected
- ✅ ronaldo receives messi's events
- ✅ Summary file created with events from both users
- ✅ Events sorted chronologically by time
- ✅ Database shows 2 users, 2 login sessions

---

### Scenario 3: Multiple Channels ⭐⭐
**Client 1 (messi):**
1. join Spain_Italy
2. join Germany_Japan
3. report events (will send to Germany_Japan based on team names)

**Client 2 (ronaldo):**
1. join Spain_Italy (only this channel)
2. (should NOT receive Germany_Japan events)

**Expected:**
- ✅ Channel isolation works
- ✅ Messages only delivered to correct subscribers

---

### Scenario 4: Error Handling ⭐⭐
**Test cases:**
1. Send before subscribing → ERROR
2. Subscribe before login → ERROR
3. Report non-existent file → Client error
4. Wrong password → ERROR
5. Duplicate login (same user) → ERROR
6. Disconnect without receipt → ERROR

---

### Scenario 5: SQL Integration ⭐⭐⭐ (NEW)
**Test sequence:**
1. Start Python SQL server
2. Start Java STOMP server
3. Client logs in → Check users table
4. Client logs in again → Check login_history (2 records)
5. Client logs out → Check logout_time updated
6. Client reports file → Check file_tracking table
7. Restart servers → Check data persists

**Database queries to run:**
```sql
SELECT * FROM users;
SELECT * FROM login_history ORDER BY login_time DESC;
SELECT * FROM file_tracking;
```

---

### Scenario 6: Concurrency & Thread Safety ⭐⭐⭐
**Test:**
- 5 clients login simultaneously
- All join same channel
- All send events simultaneously
- Check no data corruption
- Check no race conditions
- Check database has correct counts

---

### Scenario 7: SAFETY REQUIREMENTS ⭐⭐⭐

#### SAFETY #1: Logout with IS NULL
**Test:**
```
1. messi login (session 1)
2. messi logout (session 1 closed)
3. messi login (session 2)
4. messi logout (session 2 closed)
```
**Database check:**
```sql
SELECT * FROM login_history WHERE username='messi';
-- Should show:
-- (1, messi, time1, logout_time1)
-- (2, messi, time2, logout_time2)
-- Both should have logout_time filled
```

#### SAFETY #2: TCP Buffer Safety
**Test:** Send large SQL query (>2KB) to Python server
```python
big_query = "SELECT " + ", ".join([f"'{i}' as col{i}" for i in range(300)])
# Should receive complete response
```

#### SAFETY #3: Synchronized executeSQL
**Test:** 10 threads simultaneously calling executeSQL()
```
No data corruption
No socket errors
All queries succeed
```

---

## 📊 AUTOMATED TEST SCRIPTS

### Test 1: Quick Smoke Test (30 seconds)
**File:** `tests/quick_smoke_test.sh`
**Runs:**
- Compile client & server
- Start servers
- Single client login/join/report/logout
- Verify no crashes

### Test 2: Full Integration Test (2 minutes)
**File:** `tests/full_integration_test.sh`
**Runs:**
- All 7 critical scenarios
- Database validation
- Concurrent clients
- Error cases

### Test 3: SQL-Specific Tests (1 minute)
**File:** `tests/sql_integration_test.sh`
**Runs:**
- Python SQL server tests
- Java ↔ SQL communication
- Database persistence
- All 3 tables validation

### Test 4: Stress Test (5 minutes)
**File:** `tests/stress_test.sh`
**Runs:**
- 10 concurrent clients
- 1000 messages
- Memory leak check
- Performance metrics

---

## 🛠️ MANUAL TEST CHECKLIST

### Pre-Test Setup
- [ ] Compile client: `cd client && make`
- [ ] Compile server: `cd server && mvn compile`
- [ ] Clean database: `rm data/stomp_server.db`

### Server Startup
- [ ] Terminal 1: `cd data && python3 sql_server.py 7778`
- [ ] Terminal 2: `cd server && mvn exec:java -Dexec.args="7777 tpc"`

### Client Tests
- [ ] Terminal 3: `cd client && ./bin/StompWCIClient`
  - [ ] login 127.0.0.1:7777 user1 pass1
  - [ ] join Germany_Japan
  - [ ] report ./data/events1.json
  - [ ] logout

### Database Verification
- [ ] Check users table populated
- [ ] Check login_history has records
- [ ] Check file_tracking has records
- [ ] Verify foreign keys work
- [ ] Verify logout_time updates correctly

### Error Cases
- [ ] Try send before subscribe
- [ ] Try subscribe before login
- [ ] Try wrong password
- [ ] Try disconnect without receipt

---

## 📈 SUCCESS CRITERIA

### Client (Section 3.1)
✅ All commands work  
✅ Thread-safe operations  
✅ Correct STOMP frame formatting  
✅ Event parsing works  
✅ Summary file creation works  

### Server (Section 3.2)
✅ TPC server works  
✅ Reactor server works  
✅ STOMP protocol handling correct  
✅ Channel subscriptions work  
✅ Message delivery correct  
✅ Error frames sent properly  

### SQL Integration (Section 3.3)
✅ Python SQL server runs  
✅ Java connects to SQL server  
✅ Database tables created  
✅ Login/logout tracked  
✅ File uploads tracked  
✅ Data persists after restart  
✅ All 3 SAFETY requirements pass  

### Overall
✅ No crashes  
✅ No memory leaks  
✅ No race conditions  
✅ No data corruption  
✅ Full PDF compliance  

---

## 🎓 GRADING ALIGNMENT

| Assignment Section | Tests Coverage | Files |
|-------------------|----------------|-------|
| **3.1 Client** | Unit + Integration | test_frame_format, test_event_parsing |
| **3.2 Server** | Integration + Stress | full_integration, stress_test |
| **3.3 SQL** | SQL-specific + Safety | sql_integration_test |

---

## 🚀 QUICK START

```bash
# Run ALL tests
cd /workspaces/Assignment\ 3\ SPL
./tests/run_all_tests.sh

# Run specific test level
./tests/quick_smoke_test.sh
./tests/full_integration_test.sh
./tests/sql_integration_test.sh
./tests/stress_test.sh
```

---

## 📝 TEST EXECUTION LOG

**Date:** ___________  
**Tester:** ___________

| Test | Status | Notes |
|------|--------|-------|
| Unit Tests | ⬜ | |
| Smoke Test | ⬜ | |
| Integration Test | ⬜ | |
| SQL Test | ⬜ | |
| Stress Test | ⬜ | |
| Safety #1 | ⬜ | |
| Safety #2 | ⬜ | |
| Safety #3 | ⬜ | |

---

**Next:** See individual test scripts in `/planning/tests/` directory.
