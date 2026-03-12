#!/usr/bin/env python3
"""
Compare RSVCE and NABRE database structures
"""

import sqlite3
from pathlib import Path

def inspect_db(db_path: str, name: str):
    """Inspect database structure"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print(f"\n{'='*80}")
    print(f"{name} DATABASE STRUCTURE")
    print(f"{'='*80}")
    
    # Get all tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cursor.fetchall()]
    print(f"\nTables: {', '.join(tables)}")
    
    # Check books table
    if 'books' in tables:
        cursor.execute("PRAGMA table_info(books)")
        columns = cursor.fetchall()
        print(f"\nBooks table columns:")
        for col in columns:
            print(f"  - {col[1]} ({col[2]})")
        
        cursor.execute("SELECT COUNT(*) FROM books")
        print(f"  Total books: {cursor.fetchone()[0]}")
    
    # Check verses table
    if 'verses' in tables:
        cursor.execute("PRAGMA table_info(verses)")
        columns = cursor.fetchall()
        print(f"\nVerses table columns:")
        for col in columns:
            print(f"  - {col[1]} ({col[2]})")
        
        cursor.execute("SELECT COUNT(*) FROM verses")
        print(f"  Total verses: {cursor.fetchone()[0]}")
    
    # Sample verse
    cursor.execute("""
        SELECT b.shortname, v.chapter_id, v.verse_id, v.text
        FROM verses v
        JOIN books b ON b._id = v.book_id
        WHERE b.shortname = 'John' AND v.chapter_id = 3 AND v.verse_id = 16
    """)
    row = cursor.fetchone()
    if row:
        print(f"\nSample verse (John 3:16):")
        print(f"  {row[3][:100]}...")
    
    conn.close()

if __name__ == '__main__':
    base_path = Path(__file__).parent.parent / 'assets'
    
    rsvce_path = base_path / 'rsvce.db'
    nabre_path = base_path / 'nabre.db'
    
    if rsvce_path.exists():
        inspect_db(str(rsvce_path), 'RSVCE')
    else:
        print(f"RSVCE database not found at {rsvce_path}")
    
    if nabre_path.exists():
        inspect_db(str(nabre_path), 'NABRE')
    else:
        print(f"NABRE database not found at {nabre_path}")
