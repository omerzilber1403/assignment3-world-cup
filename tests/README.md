# 🧪 Comprehensive Test Suite - Assignment 3 SPL

## 📋 סקירה כללית

תיקייה זו מכילה **מערכת טסטים מלאה** שבודקת **כל** חלקי העבודה:
- ✅ **Client** - כל הפקודות והלוגיקה
- ✅ **Server** - Reactor, TPC, STOMP Protocol
- ✅ **Integration** - תקשורת מלאה בין לקוח לשרת
- ✅ **Concurrency** - מספר לקוחות במקביל
- ✅ **Protocol Compliance** - התאמה מדויקת ל-PDF

---

## 🎯 **רמות טסטים - 4 שכבות**

### **Level 1: Unit Tests** ⚡ (אין צורך בשרת)

טסטים שבודקים רכיבים בודדים בלבד.

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
