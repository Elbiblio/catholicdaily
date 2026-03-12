#!/usr/bin/env python3
"""
Check psalm response for a specific date
"""

import sqlite3
from pathlib import Path
from datetime import datetime

def check_date(db_path: str, date_str: str):
    """Check psalm response for a specific date"""
    year, month, day = map(int, date_str.split('-'))
    date = datetime(year, month, day, 8, 0, 0)
    timestamp = int(date.timestamp())
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print(f"\nChecking readings for {date_str}:")
    print("=" * 80)
    
    cursor.execute('''
        SELECT position, reading, psalm_response, gospel_acclamation
        FROM readings 
        WHERE timestamp = ?
        ORDER BY position
    ''', (timestamp,))
    
    rows = cursor.fetchall()
    
    for position, reading, psalm_resp, gospel_acc in rows:
        print(f"\nPosition {position}: {reading}")
        if psalm_resp:
            print(f"  Psalm Response: {psalm_resp[:100]}{'...' if len(psalm_resp) > 100 else ''}")
        if gospel_acc:
            print(f"  Gospel Acclamation: {gospel_acc[:100]}{'...' if len(gospel_acc) > 100 else ''}")
    
    conn.close()

if __name__ == '__main__':
    db_path = Path(__file__).parent.parent / 'assets' / 'readings.db'
    
    if not db_path.exists():
        print(f"Error: Database not found at {db_path}")
        exit(1)
    
    # Check March 18, 2026
    check_date(str(db_path), '2026-03-18')
    
    # Check a few more dates
    check_date(str(db_path), '2026-03-19')
    check_date(str(db_path), '2026-03-20')
