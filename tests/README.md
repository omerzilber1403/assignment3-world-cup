# 🧪 Comprehensive Test Suite - Assignment 3 SPL

## 📋 סקירה כללית

תיקייה זו מכילה **מערכת טסטים מלאה** שבודקת **כל** חלקי העבודה:
- ✅ **Client** (Section 3.1) - כל הפקודות והלוגיקה
- ✅ **Server** (Section 3.2) - Reactor, TPC, STOMP Protocol
- ✅ **SQL Integration** (Section 3.3) - Database + Safety Requirements
- ✅ **Integration** - תקשורת מלאה בין לקוח לשרת
- ✅ **Concurrency** - מספר לקוחות במקביל

---

## 🚀 **איך להריץ את כל הטסטים? (RECOMMENDED)**

```bash
cd /workspaces/Assignment\ 3\ SPL
./tests/run_all_tests.sh
```

**משך זמן:** ~4 דקות  
**תוצאה:** סיכום מלא של כל הטסטים

---

## 📊 **טסטים זמינים**

### 1️⃣ Quick Smoke Test (30 seconds)
```bash
./tests/quick_smoke_test.sh
```
**בודק:**
- קומפילציה (client + server)
- הפעלת שרתים (SQL + STOMP)
- חיבור בסיסי
- יצירת database

**תוצאה מצופה:**
```
✅ PASS: Client compiled
✅ PASS: Server compiled
✅ PASS: Python SQL Server started
✅ PASS: STOMP Server operational
✅ SMOKE TEST PASSED
```

---

### 2️⃣ SQL Integration Test (60 seconds) - **SECTION 3.3**
```bash
./tests/sql_integration_test.sh
```
**בודק:**
- ✅ Database initialization (3 tables)
- ✅ INSERT/SELECT/UPDATE operations
- ✅ **SAFETY #1:** Logout logic with IS NULL
- ✅ **SAFETY #2:** TCP buffer safety (loop until \0)
- ✅ **SAFETY #3:** Concurrent access (10 threads)
- ✅ File tracking
- ✅ Data persistence after restart

**תוצאה מצופה:**
```
✅ Test 1: Database Initialization
✅ Test 2: User Registration
✅ Test 3: User Query
✅ Test 4: Login History Tracking
✅ Test 5: SAFETY #1 - Logout Logic
✅ Test 6: SAFETY #2 - TCP Buffer Safety
✅ Test 7: SAFETY #3 - Concurrent Access
✅ SQL INTEGRATION TEST PASSED
```

---

### 3️⃣ Full Integration Test (120 seconds) - **SECTIONS 3.1 + 3.2**
```bash
./tests/full_integration_test.sh
```
**בודק:**
- Scenario 1: Single user workflow (login → join → report → logout)
- Scenario 2: Two users exchanging messages
- Scenario 3: Error handling (wrong password, etc.)
- Scenario 4: 5 concurrent clients
- Scenario 5: File upload tracking validation

**תוצאה מצופה:**
```
✅ Scenario 1: User workflow complete
✅ Scenario 2: Both users registered
✅ Wrong password rejected correctly
✅ Scenario 4: 5+ users handled concurrently
✅ FULL INTEGRATION TEST PASSED
```

---

### 4️⃣ Unit Tests (C++) - **CLIENT VALIDATION**
```bash
cd tests
make test
./test_frame_format
./test_event_parsing
```
**בודק:**
- STOMP frame formatting (PDF compliance)
- JSON event parsing
- Frame parsing from server

#### 📄 `test_frame_format.cpp` - בדיקת פורמט Frames

בודק ש-**כל סוגי ה-frames** שהלקוח בונה תואמים למפרט:

#### ✅ **Test 1: CONNECT Frame**
- בודק שיש `CONNECT` בתחילה
- בודק שיש headers: `accept-version:1.2`, `host`, `login`, `passcode`
- בודק שיש שורה ריקה בין headers ל-body
- **מדמה בדיוק את הדוגמה מה-PDF עמוד 13**

#### ✅ **Test 2: SUBSCRIBE Frame**
- בודק `destination:/usa_mexico`
- בודק `id:17` (מספר subscription)
- בודק `receipt:73`
- **מדמה את הדוגמה מה-PDF עמוד 14**

#### ✅ **Test 3: UNSUBSCRIBE Frame**
- בודק ש**אין** `destination` header (שגיאה נפוצה!)
- בודק שיש `id:17` (אותו ID מה-SUBSCRIBE)
- בודק `receipt:82`
- **מדמה את הדוגמה מה-PDF עמוד 14**

#### ✅ **Test 4: SEND Frame with Body**
- בודק `destination:/usa_mexico`
- בודק שהגוף מכיל את כל השדות הנדרשים:
  - `user: meni`
  - `team a: USA`
  - `team b: Mexico`
  - `event name:`, `time:`
  - `general game updates:`, `team a updates:`, etc.
- בודק שיש שורה ריקה בין headers לגוף

#### ✅ **Test 5: DISCONNECT Frame**
- בודק שיש `receipt` header (חובה!)

#### ✅ **Test 6: Frame Parsing**
- בודק שאנחנו יכולים גם **לקרוא** frames מהשרת
- מדמה קבלת MESSAGE frame

---

### 2️⃣ `test_event_parsing.cpp` - בדיקת ניתוח Events

#### ✅ **Test 1: JSON File Parsing**
- קורא את `events1_partial.json`
- בודק שמחלצים נכון: team names, events list
- בודק שיש game updates, team updates

#### ✅ **Test 2: Event from Frame Body**
- בונה event מגוף MESSAGE frame
- בודק שהניתוח נכון:
  - `team a: USA` → `get_team_a_name() == "USA"`
  - `time: 45` → `get_time() == 45`
  - game updates, team updates, description

---

## 🚀 איך להריץ את הטסטים?

### אופציה 1: הרצה מהירה
```bash
cd tests
make test
```

### אופציה 2: הרצה ידנית של טסט ספציפי
```bash
cd tests
make test_frame_format
./test_frame_format

make test_event_parsing
./test_event_parsing
```

### אופציה 3: ניקוי
```bash
cd tests
make clean
```

---

## 📊 מה הטסטים בודקים?

| טסט | מה זה בודק | למה זה חשוב |
|-----|-------------|--------------|
| **CONNECT format** | Headers נכונים לפי PDF | חיבור לשרת |
| **SUBSCRIBE format** | destination + id + receipt | הצטרפות לערוץ |
| **UNSUBSCRIBE format** | משתמש ב-id ולא destination | יציאה מערוץ (שגיאה נפוצה!) |
| **SEND with body** | גוף מלא עם כל השדות | שליחת דיווח |
| **Frame parsing** | קריאת frames מהשרת | קבלת הודעות |
| **JSON parsing** | קריאת קובץ events | פקודת report |
| **Event from body** | בניית Event מ-MESSAGE | עיבוד הודעות שמגיעות |

---

## ✅ תוצאות צפויות

אם הכל עובד, תראה:

```
╔═══════════════════════════════════════════════════════╗
║  STOMP Frame Format Tests - PDF Compliance Check    ║
╚═══════════════════════════════════════════════════════╝

=== Test 1: CONNECT Frame Format ===
Generated frame:
CONNECT
accept-version:1.2
host:stomp.cs.bgu.ac.il
login:meni
passcode:films

---END---
✅ PASSED: Frame starts with CONNECT
✅ PASSED: Contains accept-version header
✅ PASSED: Contains host header
✅ PASSED: Contains login header
✅ PASSED: Contains passcode header
✅ PASSED: Empty line separator exists

... (שאר הטסטים) ...

╔═══════════════════════════════════════════════════════╗
║  ✅ ALL TESTS PASSED!                                ║
║  All frames match PDF specification                  ║
╚═══════════════════════════════════════════════════════╝
```

---

## 🔍 למה הטסטים האלה חשובים?

1. **Compliance**: מוודאים שאנחנו עומדים במפרט המדויק של ה-PDF
2. **Early Detection**: תופסים שגיאות לפני שהשרת דחה את ה-frames
3. **Documentation**: הטסטים מתעדים בדיוק איך frames צריכים להיראות
4. **Regression**: אם נשנה משהו, הטסטים יגלו אם שברנו משהו

---

## 📝 הערות

- הטסטים **לא משנים** את הקוד של הלקוח
- הם רק **בודקים** שהקוד עובד נכון
- כל טסט מדפיס את ה-frame שהוא בנה - אפשר לראות בדיוק מה נשלח
- אם טסט נכשל, הוא מדפיס מה היה ומה ציפינו

---

## 🎯 טסטים עתידיים (אפשר להוסיף)

- [ ] בדיקת null terminator (`\0`) בפועל
- [ ] בדיקת subscription ID counter (unique IDs)
- [ ] בדיקת receipt ID counter
- [ ] בדיקת מיון כרונולוגי ב-summary
- [ ] בדיקת מיון לקסיקוגרפי של stats
- [ ] בדיקות integration עם שרת מזויף (mock)
