#!/usr/bin/env python3
"""
Check detailed data for March 18, 2026
"""

import sqlite3
from pathlib import Path
from datetime import datetime

def check_march_18(db_path: str):
    """Check all details for March 18, 2026"""
    date = datetime(2026, 3, 18, 8, 0, 0)
    timestamp = int(date.timestamp())
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("\n" + "=" * 80)
    print("MARCH 18, 2026 - DETAILED DATA")
    print("=" * 80)
    
    cursor.execute('''
        SELECT position, reading, psalm_response, gospel_acclamation
        FROM readings 
        WHERE timestamp = ?
        ORDER BY position
    ''', (timestamp,))
    
    rows = cursor.fetchall()
    
    for position, reading, psalm_resp, gospel_acc in rows:
        print(f"\n{'='*80}")
        print(f"Position {position}: {reading}")
        print(f"{'='*80}")
        
        if psalm_resp:
            print(f"\nPsalm Response (length: {len(psalm_resp)}):")
            print(f"'{psalm_resp}'")
            print(f"\nFirst 100 chars: {psalm_resp[:100]}")
        else:
            print("\nPsalm Response: NULL")
        
        if gospel_acc:
            print(f"\nGospel Acclamation (length: {len(gospel_acc)}):")
            print(f"'{gospel_acc}'")
            print(f"\nFirst 100 chars: {gospel_acc[:100]}")
        else:
            print("\nGospel Acclamation: NULL")
    
    conn.close()

if __name__ == '__main__':
    db_path = Path(__file__).parent.parent / 'assets' / 'readings.db'
    
    if not db_path.exists():
        print(f"Error: Database not found at {db_path}")
        exit(1)
    
    check_march_18(str(db_path))
