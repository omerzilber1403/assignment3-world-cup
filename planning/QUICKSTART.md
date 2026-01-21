# ⚡ QUICK START GUIDE - Assignment 3 SPL

**למי שרוצה להריץ במהירות!**

---

## 🚀 הרצה מהירה (30 שניות)

```bash
cd /workspaces/Assignment\ 3\ SPL
./tests/quick_smoke_test.sh
```

**אם ראית:**
```
✅ SMOKE TEST PASSED
```
**→ הכל עובד!** ✅

---

## 🧪 בדיקה מלאה (4 דקות)

```bash
cd /workspaces/Assignment\ 3\ SPL
./tests/run_all_tests.sh
```

**אם ראית:**
```
🎉 ALL TESTS PASSED - Assignment ready for submission!
```
**→ מוכן להגשה!** 🎉

---

## 🎯 הפעלה ידנית (למי שרוצה לראות בעצמו)

### טרמינל 1: Python SQL Server
```bash
cd /workspaces/Assignment\ 3\ SPL/data
python3 sql_server.py 7778
```
צריך לראות:
```
[STOMP_PYTHON_SQL_SERVER] Database initialized: stomp_server.db
[STOMP_PYTHON_SQL_SERVER] Server started on 127.0.0.1:7778
```

### טרמינל 2: Java STOMP Server
```bash
cd /workspaces/Assignment\ 3\ SPL/server
mvn exec:java -Dexec.mainClass="bgu.spl.net.impl.stomp.StompServer" -Dexec.args="7777 tpc"
```
צריך לראות:
```
Server started
```

### טרמינל 3: Client (messi)
```bash
cd /workspaces/Assignment\ 3\ SPL/client
./bin/StompWCIClient
```
הקלד:
```
login 127.0.0.1:7777 messi pass123
join Germany_Japan
report ./data/events1.json
```

### טרמינל 4: Client (ronaldo)
```bash
cd /workspaces/Assignment\ 3\ SPL/client
./bin/StompWCIClient
```
הקלד:
```
login 127.0.0.1:7777 ronaldo pass456
join Germany_Japan
summary Germany_Japan messi ronaldo
logout
```

---

## 📊 בדיקת Database

```bash
cd /workspaces/Assignment\ 3\ SPL/data
python3 << 'EOF'
import sqlite3
conn = sqlite3.connect('stomp_server.db')
cursor = conn.cursor()

print("📊 USERS:")
cursor.execute("SELECT username FROM users")
for row in cursor.fetchall():
    print(f"  • {row[0]}")

print("\n🔐 LOGIN HISTORY:")
cursor.execute("SELECT username, login_time, logout_time FROM login_history")
for row in cursor.fetchall():
    logout = row[2] if row[2] else "still active"
    print(f"  • {row[0]}: {row[1]} → {logout}")

print("\n📁 FILE UPLOADS:")
cursor.execute("SELECT username, filename, game_channel FROM file_tracking")
for row in cursor.fetchall():
    print(f"  • {row[0]} uploaded {row[1]} to {row[2]}")

conn.close()
EOF
```

---

## 🛑 עצירת השרתים

```bash
pkill -f "sql_server.py"
pkill -f "StompServer"
pkill -f "StompWCIClient"
```

---

## 🧹 ניקוי

```bash
cd /workspaces/Assignment\ 3\ SPL
rm -f data/stomp_server.db*
rm -f /tmp/test_*.log
rm -f /tmp/integration_*.log
```

---

## ❓ בעיות נפוצות

### 1. "Command not found"
```bash
cd /workspaces/Assignment\ 3\ SPL
chmod +x tests/*.sh
```

### 2. "Port already in use"
```bash
pkill -f "sql_server|StompServer"
sleep 2
# נסה שוב
```

### 3. "Database locked"
```bash
rm -f data/stomp_server.db*
# התחל מחדש את SQL server
```

### 4. Compilation errors
```bash
cd client && make clean && make
cd ../server && mvn clean compile
```

---

## 📚 מסמכים נוספים

- `/planning/COMPREHENSIVE_TEST_PLAN.md` - תכנית טסטים מלאה
- `/planning/TEST_SUITE_DOCUMENTATION.md` - תיעוד טסטים
- `/planning/TEST_EXECUTION_REPORT.md` - דוח תוצאות
- `/planning/FINAL_VALIDATION_SUMMARY.md` - סיכום סופי
- `/tests/README.md` - הסבר על הטסטים

---

## ✅ סיכום מהיר

| מה | איפה | כמה זמן |
|----|------|----------|
| **בדיקה מהירה** | `./tests/quick_smoke_test.sh` | 30s |
| **בדיקה מלאה** | `./tests/run_all_tests.sh` | 4min |
| **הפעלה ידנית** | 3 טרמינלים (למעלה) | 2min |

---

**🎯 המטרה: לראות ✅ PASSED בכל הטסטים**

**🚀 בהצלחה!**
