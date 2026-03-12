#!/usr/bin/env python3
"""
Find March 18, 2026 data with different timestamp approaches
"""

import sqlite3
from pathlib import Path
from datetime import datetime, timezone

def find_march_18(db_path: str):
    """Try different timestamp calculations to find March 18, 2026"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("\n" + "=" * 80)
    print("SEARCHING FOR MARCH 18, 2026")
    print("=" * 80)
    
    # Try different timestamp calculations
    attempts = [
        ("UTC 8am", datetime(2026, 3, 18, 8, 0, 0, tzinfo=timezone.utc)),
        ("Local 8am", datetime(2026, 3, 18, 8, 0, 0)),
        ("UTC midnight", datetime(2026, 3, 18, 0, 0, 0, tzinfo=timezone.utc)),
        ("Local midnight", datetime(2026, 3, 18, 0, 0, 0)),
    ]
    
    for label, dt in attempts:
        ts = int(dt.timestamp())
        print(f"\n{label}: timestamp = {ts}")
        
        cursor.execute('''
            SELECT COUNT(*) FROM readings 
            WHERE timestamp >= ? AND timestamp < ?
        ''', (ts, ts + 86400))
        
        count = cursor.fetchone()[0]
        print(f"  Found {count} readings")
        
        if count > 0:
            cursor.execute('''
                SELECT position, reading, psalm_response, gospel_acclamation
                FROM readings 
                WHERE timestamp >= ? AND timestamp < ?
                ORDER BY position
            ''', (ts, ts + 86400))
            
            for pos, reading, psalm_resp, gospel_acc in cursor.fetchall():
                print(f"\n  Position {pos}: {reading}")
                if psalm_resp:
                    print(f"    Psalm: {psalm_resp[:60]}...")
                if gospel_acc:
                    print(f"    Acclamation: {gospel_acc[:60]}...")
    
    # Also search by date string pattern
    print("\n" + "=" * 80)
    print("SEARCHING ALL 2026-03-18 ENTRIES")
    print("=" * 80)
    
    cursor.execute('''
        SELECT timestamp, position, reading, psalm_response, gospel_acclamation
        FROM readings 
        WHERE timestamp >= ? AND timestamp < ?
        ORDER BY timestamp, position
    ''', (int(datetime(2026, 3, 18).timestamp()), int(datetime(2026, 3, 19).timestamp())))
    
    rows = cursor.fetchall()
    print(f"\nFound {len(rows)} total readings for 2026-03-18")
    
    for ts, pos, reading, psalm_resp, gospel_acc in rows:
        dt = datetime.fromtimestamp(ts)
        print(f"\n{dt} (ts={ts}) | Position {pos}: {reading}")
        if psalm_resp:
            print(f"  Psalm Response: {psalm_resp}")
        if gospel_acc:
            print(f"  Gospel Acclamation: {gospel_acc}")
    
    conn.close()

if __name__ == '__main__':
    db_path = Path(__file__).parent.parent / 'assets' / 'readings.db'
    
    if not db_path.exists():
        print(f"Error: Database not found at {db_path}")
        exit(1)
    
    find_march_18(str(db_path))
