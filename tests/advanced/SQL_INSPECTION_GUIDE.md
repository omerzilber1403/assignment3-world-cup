# SQL Database Inspection Guide - Assignment 3 SPL

## 🎯 מטרה

להבין מה יש במסד הנתונים ולוודא שהכל עובד נכון.

## 🚀 איך להריץ את כלי הצפייה

### אופציה 1: Python Script (מומלץ!)

```bash
cd tests/advanced
python3 view_database.py
```

**זה יראה לך:**
- ✅ כל 3 הטבלאות בפורמט יפה
- ✅ סטטיסטיקות על המידע
- ✅ בדיקות שלמות נתונים
- ✅ אימות דרישות בטיחות

### אופציה 2: SQLite Command Line

```bash
cd data
sqlite3 stomp_server.db

# פקודות לתוך sqlite:
.tables                    # רשימת כל הטבלאות
.schema users             # מבנה טבלת users
SELECT * FROM users;      # כל המשתמשים
.exit                     # יציאה
```

### אופציה 3: DB Browser for SQLite (ממשק גרפי)

1. הורד: https://sqlitebrowser.org/
2. פתח: `data/stomp_server.db`
3. לחץ על "Browse Data"
4. בחר טבלה לצפייה

## 📊 מבנה ה-Database

### טבלה 1: `users`

```
┌──────────┬──────────┐
│ username │ password │  ← PRIMARY KEY: username
├──────────┼──────────┤
│ messi    │ pass123  │
│ ronaldo  │ pass456  │
│ fan1     │ pass1    │
└──────────┴──────────┘
```

**מה אמור להיות שם:**
- כל משתמש שעשה `login` (CONNECT)
- Username = unique
- Password = מאוחסן (לא מוצפן בפרויקט הזה)

**איך זה מתמלא:**
```
Client → CONNECT frame → Java Server → SQL INSERT INTO users
```

---

### טבלה 2: `login_history`

```
┌────┬──────────┬─────────────────────┬─────────────────────┐
│ id │ username │ login_time          │ logout_time         │
├────┼──────────┼─────────────────────┼─────────────────────┤
│ 1  │ messi    │ 2026-01-21 01:00:00 │ 2026-01-21 01:05:00 │
│ 2  │ ronaldo  │ 2026-01-21 01:02:00 │ NULL                │ ← עדיין מחובר!
│ 3  │ messi    │ 2026-01-21 01:10:00 │ NULL                │ ← התחבר שוב
└────┴──────────┴─────────────────────┴─────────────────────┘
```

**מה אמור להיות שם:**
- **שורה חדשה** לכל login (גם אם אותו user)
- `logout_time = NULL` כל עוד המשתמש מחובר
- `logout_time` מתמלא כש-user עושה DISCONNECT

**⚠️ SAFETY #1 - חשוב!**
```sql
-- כשמשתמש עושה logout, השרת מריץ:
UPDATE login_history 
SET logout_time = datetime('now') 
WHERE username = 'messi' AND logout_time IS NULL;
```

**למה `IS NULL`?** כדי לעדכן רק את הסשן האקטיבי, לא את כל ההיסטוריה!

---

### טבלה 3: `file_tracking`

```
┌────┬──────────┬────────────────┬─────────────────────┐
│ id │ username │ filename       │ upload_time         │
├────┼──────────┼────────────────┼─────────────────────┤
│ 1  │ messi    │ events1.json   │ 2026-01-21 01:03:00 │
│ 2  │ ronaldo  │ events2.json   │ 2026-01-21 01:04:00 │
│ 3  │ fan1     │ my_events.json │ 2026-01-21 01:06:00 │
└────┴──────────┴────────────────┴─────────────────────┘
```

**מה אמור להיות שם:**
- כל פעם ש-client עושה `report <filename>`
- שורה חדשה עבור כל קובץ

**איך זה מתמלא:**
```
Client → report events.json → Java Server → SQL INSERT INTO file_tracking
```

## ✅ מה אתה אמור לראות אחרי הטסטים

### אחרי `test_sql_concurrency.sh`:
```
users: 10+ users (user0, user1, ..., user9, stressuser0, etc.)
login_history: 10+ login records
file_tracking: 10+ file uploads
```

### אחרי `test_stress_10_clients.sh`:
```
users: +10 users (stressuser0-9)
login_history: +10 sessions
file_tracking: ~100 records (10 clients × 10 events each)
```

### אחרי `test_full_game_scenario.sh`:
```
users: Mueller, Tanaka, Schmidt
login_history: 3 sessions (all with logout_time filled)
file_tracking: ~9 events (from match scenario)
```

## 🔍 שאילתות SQL שימושיות

### בדיקה כללית:
```sql
-- כמה users יש?
SELECT COUNT(*) FROM users;

-- כמה sessions פעילים כרגע?
SELECT COUNT(*) FROM login_history WHERE logout_time IS NULL;

-- מי המשתמשים הכי פעילים?
SELECT username, COUNT(*) as logins 
FROM login_history 
GROUP BY username 
ORDER BY logins DESC;
```

### בדיקת SAFETY #1:
```sql
-- האם יש users עם 2+ sessions פעילים? (לא צריך להיות!)
SELECT username, COUNT(*) as active_sessions
FROM login_history
WHERE logout_time IS NULL
GROUP BY username
HAVING active_sessions > 1;

-- Expected result: 0 rows (no one should have multiple active sessions)
```

### בדיקת timestamps:
```sql
-- ראה את ה-10 logins האחרונים
SELECT username, login_time, logout_time 
FROM login_history 
ORDER BY login_time DESC 
LIMIT 10;
```

### בדיקת file uploads:
```sql
-- מי העלה הכי הרבה קבצים?
SELECT username, COUNT(*) as uploads
FROM file_tracking
GROUP BY username
ORDER BY uploads DESC;
```

## 🐛 בעיות נפוצות ופתרונות

### בעיה: "Database not found"
```bash
# פתרון: התחל את ה-SQL server תחילה
cd data
python3 sql_server.py 7778

# ב-terminal אחר:
cd server
mvn exec:java -Dexec.args="7777 tpc"

# חבר client אחד כדי ליצור את ה-DB
cd client
./bin/StompWCIClient
# הקלד: login 127.0.0.1:7777 testuser testpass
```

### בעיה: "Table doesn't exist"
```bash
# הטבלאות נוצרות אוטומטית על ידי Python SQL server
# ודא ש-sql_server.py רץ ושה-schema נוצר
```

### בעיה: "כל ה-logout_time הם NULL"
```bash
# זה אומר שהלקוחות לא עשו DISCONNECT נכון
# ודא שהלקוחות שולחים DISCONNECT frame לפני סגירה
```

## 📈 מה אתה צריך לבדוק לפני הגשה

1. **יש לפחות 3 users** בטבלת users
2. **login_history** יש records עם logout_time מלא (לא רק NULL)
3. **file_tracking** יש records מ-report commands
4. **אין users עם 2+ active sessions** (SAFETY #1)
5. **כל username ב-login_history קיים ב-users** (foreign key integrity)

## 🎓 טיפים

1. **נקה את ה-DB לפני בדיקה:**
   ```bash
   rm data/stomp_server.db
   # התחל מחדש את השרתים
   ```

2. **צפה בזמן אמת:**
   ```bash
   # Terminal 1: הרץ script שצופה
   watch -n 2 'python3 tests/advanced/view_database.py'
   
   # Terminal 2: הרץ טסטים
   cd tests/advanced
   ./run_advanced_suite.sh
   ```

3. **שמור snapshot לפני/אחרי:**
   ```bash
   cp data/stomp_server.db data/backup_before_tests.db
   # Run tests
   # Compare results
   ```

---

**Created**: January 21, 2026  
**תפקיד**: עזרה להבנת מסד הנתונים ואימות שהכל עובד
