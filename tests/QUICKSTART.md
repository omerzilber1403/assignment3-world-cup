# ⚡ **Quick Start Guide - Running Tests**

## 🚀 **Option 1: Fast (Unit Tests Only - No Server)**

רק טסטים מהירים, **ללא צורך בשרת**:

```bash
cd tests
make test
```

✅ **זמן: 2 שניות**  
✅ **8 טסטים**  
✅ **בודק: Frame format + Event parsing**

---

## 🔥 **Option 2: Full (All Tests)**

### **Step 1: Start Server**

**Option A - Using helper script:**
```bash
cd tests
./start_server.sh
```

**Option B - Manual:**
```bash
cd server
mvn exec:java -Dexec.mainClass="bgu.spl.net.impl.stomp.StompServer" -Dexec.args="7777"
```

השאר את Terminal הזה **רץ** (Ctrl+C לעצור).

---

### **Step 2: Run Tests (Terminal חדש)**

```bash
cd tests
make full-test
```

✅ **זמן: 30 שניות**  
✅ **21 טסטים**  
✅ **בודק: הכל!**

---

## 🎯 **Option 3: Specific Tests**

### **Unit Tests (no server):**
```bash
cd tests
make unit-test
```

### **Integration Tests (needs server):**
```bash
cd tests
make integration-test
```

### **Client Commands (needs server):**
```bash
cd tests
make client-test
```

### **Stress Test (needs server):**
```bash
cd tests
make stress-test
```

---

## 📊 **What Gets Tested:**

| Test Level | Tests | What | Time |
|------------|-------|------|------|
| **Unit** | 8 | Frame format + Event parsing | 2s |
| **Integration** | 7 | Client ↔ Server communication | 10s |
| **Commands** | 5 | All client commands | 10s |
| **Stress** | 1 | 10 concurrent clients | 8s |
| **TOTAL** | **21** | **Everything!** | **30s** |

---

## ✅ **Expected Output:**

```
╔════════════════════════════════════════════════════════╗
║  ✅ ALL 21 TESTS PASSED!                               ║
║  Server + Client working perfectly!                   ║
╚════════════════════════════════════════════════════════╝
```

---

## 🆘 **Troubleshooting:**

### **"Cannot connect to server"**
→ Make sure server is running: `./start_server.sh`

### **"Client binary not found"**
→ Build client first:
```bash
cd client
make
```

### **Some tests fail**
→ Run individual test to debug:
```bash
cd tests
./test_frame_format        # Unit test
./test_full_integration    # Integration test (needs server)
./test_client_commands.sh  # Client test (needs server)
```

---

## 📖 **More Info:**

- Full documentation: `README_FULL.md`
- Test summary: `TEST_SUMMARY.md`
- Help: `make help`
