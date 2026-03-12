#!/usr/bin/env python3
"""
Check Psalm 145:8 in RSVCE database
"""

import sqlite3
from pathlib import Path

def check_psalm_verse(db_path: str):
    """Check Psalm 145:8 text"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("\n" + "=" * 80)
    print("PSALM 145:8 IN RSVCE DATABASE")
    print("=" * 80)
    
    cursor.execute('''
        SELECT v.verse_id, v.text
        FROM verses v
        JOIN books b ON b._id = v.book_id
        WHERE b.shortname = 'Ps' AND v.chapter_id = 145 AND v.verse_id = 8
    ''')
    
    row = cursor.fetchone()
    if row:
        verse_id, text = row
        print(f"\nVerse {verse_id}:")
        print(f"'{text}'")
        print(f"\nLength: {len(text)} characters")
    else:
        print("\nVerse not found!")
    
    conn.close()

if __name__ == '__main__':
    db_path = Path(__file__).parent.parent / 'assets' / 'rsvce.db'
    
    if not db_path.exists():
        print(f"Error: Database not found at {db_path}")
        exit(1)
    
    check_psalm_verse(str(db_path))
