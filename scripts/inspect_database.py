#!/usr/bin/env python3
"""
Inspect the readings database structure and sample data
"""

import sqlite3
from pathlib import Path
from datetime import datetime

def inspect_database(db_path: str):
    """Inspect database structure and content"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("\n" + "=" * 80)
    print("DATABASE STRUCTURE")
    print("=" * 80)
    
    # Get table schema
    cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='readings'")
    schema = cursor.fetchone()
    if schema:
        print("\nReadings table schema:")
        print(schema[0])
    
    # Count total rows
    cursor.execute("SELECT COUNT(*) FROM readings")
    total = cursor.fetchone()[0]
    print(f"\nTotal readings: {total}")
    
    # Get date range
    cursor.execute("SELECT MIN(timestamp), MAX(timestamp) FROM readings")
    min_ts, max_ts = cursor.fetchone()
    if min_ts and max_ts:
        min_date = datetime.fromtimestamp(min_ts)
        max_date = datetime.fromtimestamp(max_ts)
        print(f"Date range: {min_date.strftime('%Y-%m-%d')} to {max_date.strftime('%Y-%m-%d')}")
    
    # Sample some readings
    print("\n" + "=" * 80)
    print("SAMPLE READINGS")
    print("=" * 80)
    
    cursor.execute('''
        SELECT timestamp, position, reading, psalm_response, gospel_acclamation
        FROM readings 
        ORDER BY timestamp DESC
        LIMIT 10
    ''')
    
    for ts, pos, reading, psalm_resp, gospel_acc in cursor.fetchall():
        date = datetime.fromtimestamp(ts)
        print(f"\n{date.strftime('%Y-%m-%d')} | Position {pos}: {reading}")
        if psalm_resp:
            print(f"  Psalm: {psalm_resp[:80]}{'...' if len(psalm_resp) > 80 else ''}")
        if gospel_acc:
            print(f"  Acclamation: {gospel_acc[:80]}{'...' if len(gospel_acc) > 80 else ''}")
    
    # Check for March 2026 specifically
    print("\n" + "=" * 80)
    print("MARCH 2026 READINGS")
    print("=" * 80)
    
    # Try different timestamp calculations for March 18, 2026
    test_date = datetime(2026, 3, 18, 8, 0, 0)
    test_ts = int(test_date.timestamp())
    
    print(f"\nSearching for timestamp {test_ts} ({test_date})")
    
    cursor.execute('''
        SELECT COUNT(*) FROM readings 
        WHERE timestamp >= ? AND timestamp < ?
    ''', (test_ts, test_ts + 86400))
    
    count = cursor.fetchone()[0]
    print(f"Found {count} readings for March 18, 2026")
    
    if count > 0:
        cursor.execute('''
            SELECT position, reading, psalm_response, gospel_acclamation
            FROM readings 
            WHERE timestamp >= ? AND timestamp < ?
            ORDER BY position
        ''', (test_ts, test_ts + 86400))
        
        for pos, reading, psalm_resp, gospel_acc in cursor.fetchall():
            print(f"\nPosition {pos}: {reading}")
            if psalm_resp:
                print(f"  Psalm: {psalm_resp}")
            if gospel_acc:
                print(f"  Acclamation: {gospel_acc}")
    
    conn.close()

if __name__ == '__main__':
    db_path = Path(__file__).parent.parent / 'assets' / 'readings.db'
    
    if not db_path.exists():
        print(f"Error: Database not found at {db_path}")
        exit(1)
    
    inspect_database(str(db_path))
