#!/usr/bin/env python3
"""
SQL Database Viewer - Visual inspection of Assignment 3 database
Shows all tables with formatted output
"""

import sqlite3
import os
from datetime import datetime

DB_PATH = "../../data/stomp_server.db"

def print_header(title):
    """Print a nice header"""
    print("\n" + "="*70)
    print(f"  {title}")
    print("="*70 + "\n")

def print_table(cursor, query, headers):
    """Print a table with nice formatting"""
    cursor.execute(query)
    rows = cursor.fetchall()
    
    if not rows:
        print("  (No data)")
        return
    
    # Calculate column widths
    widths = [len(h) for h in headers]
    for row in rows:
        for i, val in enumerate(row):
            widths[i] = max(widths[i], len(str(val)))
    
    # Print header
    header_line = "  " + " | ".join(h.ljust(widths[i]) for i, h in enumerate(headers))
    print(header_line)
    print("  " + "-" * (len(header_line) - 2))
    
    # Print rows
    for row in rows:
        print("  " + " | ".join(str(val).ljust(widths[i]) for i, val in enumerate(row)))
    
    print(f"\n  Total rows: {len(rows)}")

def check_database():
    """Main function to inspect database"""
    
    if not os.path.exists(DB_PATH):
        print(f"❌ Database not found at: {DB_PATH}")
        print("\nℹ️  The database will be created when you:")
        print("   1. Start the Python SQL server: python3 data/sql_server.py 7778")
        print("   2. Start the STOMP server")
        print("   3. Connect a client")
        return
    
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║           SQL DATABASE VIEWER - Assignment 3 SPL                ║")
    print("╚══════════════════════════════════════════════════════════════════╝")
    print(f"\n📁 Database: {os.path.abspath(DB_PATH)}")
    print(f"📊 Size: {os.path.getsize(DB_PATH):,} bytes")
    
    # Connect to database
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # ========== TABLE 1: USERS ==========
    print_header("TABLE 1: users")
    print("Purpose: Store registered users")
    print("Columns: username (PRIMARY KEY), password")
    print()
    
    try:
        print_table(cursor, 
                   "SELECT username, password FROM users ORDER BY username;",
                   ["Username", "Password"])
    except sqlite3.Error as e:
        print(f"  ❌ Error: {e}")
    
    print("\n✅ Expected: All users who registered (via CONNECT command)")
    print("   Example: messi, ronaldo, fan1, fan2, etc.")
    
    # ========== TABLE 2: LOGIN_HISTORY ==========
    print_header("TABLE 2: login_history")
    print("Purpose: Track all login sessions (for SAFETY #1)")
    print("Columns: id, username, login_time, logout_time")
    print()
    
    try:
        print_table(cursor,
                   "SELECT id, username, login_time, logout_time FROM login_history ORDER BY id DESC LIMIT 20;",
                   ["ID", "Username", "Login Time", "Logout Time"])
    except sqlite3.Error as e:
        print(f"  ❌ Error: {e}")
    
    print("\n✅ Expected: One row per login session")
    print("   - logout_time should be NULL while user is connected")
    print("   - logout_time filled when user disconnects")
    print("   ⚠️  SAFETY #1: Uses 'IS NULL' to find current session on logout")
    
    # Check for current sessions
    cursor.execute("SELECT COUNT(*) FROM login_history WHERE logout_time IS NULL;")
    active = cursor.fetchone()[0]
    print(f"\n   📊 Currently active sessions: {active}")
    
    # ========== TABLE 3: FILE_TRACKING ==========
    print_header("TABLE 3: file_tracking")
    print("Purpose: Track file uploads (report command)")
    print("Columns: id, username, filename, upload_time")
    print()
    
    try:
        print_table(cursor,
                   "SELECT id, username, filename, upload_time FROM file_tracking ORDER BY id DESC LIMIT 20;",
                   ["ID", "Username", "Filename", "Upload Time"])
    except sqlite3.Error as e:
        print(f"  ❌ Error: {e}")
    
    print("\n✅ Expected: One row per 'report' command")
    print("   Example: user 'messi' uploaded 'events1.json'")
    
    # ========== SUMMARY STATISTICS ==========
    print_header("DATABASE STATISTICS")
    
    cursor.execute("SELECT COUNT(*) FROM users;")
    user_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM login_history;")
    login_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM file_tracking;")
    file_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT username, COUNT(*) as logins FROM login_history GROUP BY username ORDER BY logins DESC LIMIT 5;")
    top_users = cursor.fetchall()
    
    print(f"  Total Users: {user_count}")
    print(f"  Total Login Sessions: {login_count}")
    print(f"  Total Files Uploaded: {file_count}")
    
    if top_users:
        print("\n  Most Active Users:")
        for username, count in top_users:
            print(f"    - {username}: {count} logins")
    
    # ========== FOREIGN KEY CHECK ==========
    print_header("DATA INTEGRITY CHECKS")
    
    # Check if all login_history usernames exist in users table
    cursor.execute("""
        SELECT DISTINCT lh.username 
        FROM login_history lh 
        LEFT JOIN users u ON lh.username = u.username 
        WHERE u.username IS NULL;
    """)
    orphaned_logins = cursor.fetchall()
    
    if orphaned_logins:
        print(f"  ⚠️  Found {len(orphaned_logins)} orphaned login records (username not in users table)")
    else:
        print("  ✅ All login_history records reference valid users")
    
    # Check if all file_tracking usernames exist in users table
    cursor.execute("""
        SELECT DISTINCT ft.username 
        FROM file_tracking ft 
        LEFT JOIN users u ON ft.username = u.username 
        WHERE u.username IS NULL;
    """)
    orphaned_files = cursor.fetchall()
    
    if orphaned_files:
        print(f"  ⚠️  Found {len(orphaned_files)} orphaned file records")
    else:
        print("  ✅ All file_tracking records reference valid users")
    
    # ========== SAFETY REQUIREMENTS CHECK ==========
    print_header("SAFETY REQUIREMENTS VERIFICATION")
    
    # SAFETY #1: Check logout logic
    cursor.execute("""
        SELECT username, COUNT(*) as sessions, 
               SUM(CASE WHEN logout_time IS NULL THEN 1 ELSE 0 END) as active
        FROM login_history 
        GROUP BY username 
        HAVING active > 1;
    """)
    multiple_active = cursor.fetchall()
    
    if multiple_active:
        print("  ❌ SAFETY #1 VIOLATION: Users with multiple active sessions:")
        for user, total, active in multiple_active:
            print(f"      {user}: {active} active sessions out of {total} total")
    else:
        print("  ✅ SAFETY #1: No user has multiple active sessions (IS NULL logic working)")
    
    # Check for sessions with same user
    cursor.execute("""
        SELECT username, COUNT(*) as total_sessions
        FROM login_history
        GROUP BY username
        ORDER BY total_sessions DESC
        LIMIT 5;
    """)
    session_counts = cursor.fetchall()
    
    if session_counts:
        print("\n  Session history (top 5 users):")
        for user, count in session_counts:
            print(f"    {user}: {count} sessions")
    
    conn.close()
    
    print("\n" + "="*70)
    print("  ✅ Database inspection complete!")
    print("="*70 + "\n")

def print_usage():
    """Print usage instructions"""
    print("\n" + "="*70)
    print("  HOW TO USE THIS TOOL")
    print("="*70)
    print("""
1. Make sure servers are running:
   - SQL server: python3 data/sql_server.py 7778
   - STOMP server: mvn exec:java -Dexec.args="7777 tpc"

2. Run some clients to populate data:
   - cd client
   - ./bin/StompWCIClient
   - Commands: login, join, report, logout

3. Run this script to view database:
   - python3 tests/advanced/view_database.py

4. After running tests, run this again to see results!
""")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--help":
        print_usage()
    else:
        check_database()
        
        if not os.path.exists(DB_PATH):
            print_usage()
