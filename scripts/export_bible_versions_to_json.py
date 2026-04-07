#!/usr/bin/env python3
"""
Export Bible verses from database files to version-specific JSON files for web backend.

This script reads from the two Bible databases (RSVCE, NABRE) and creates
version-specific JSON files that the web backend can use for version switching.

Usage:
    python export_bible_versions_to_json.py
"""

import sqlite3
import json
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
ASSETS_DIR = BASE_DIR / "assets"
DATA_DIR = ASSETS_DIR / "data"
SCRIPTS_DIR = BASE_DIR / "scripts"

# Database paths
RSVCE_DB = ASSETS_DIR / "rsvce.db"
NABRE_DB = ASSETS_DIR / "nabre.db"

# Output paths
BOOKS_JSON = DATA_DIR / "books_rows.json"
VERSES_RSVCE_JSON = DATA_DIR / "verses_rows_rsvce.json"
VERSES_NABRE_JSON = DATA_DIR / "verses_rows_nabre.json"

def export_books_from_db(db_path: Path) -> list[dict]:
    """Export books data from database."""
    if not db_path.exists():
        raise FileNotFoundError(f"Database not found: {db_path}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT _id, text, shortname
            FROM books
            ORDER BY _id
        """)
        
        books = []
        for row in cursor.fetchall():
            books.append({
                "_id": row[0],
                "text": row[1],
                "shortname": row[2],
                "chapter_count": 0  # Default value, not stored in database
            })
        
        return books
    
    finally:
        conn.close()

def export_verses_from_db(db_path: Path) -> list[dict]:
    """Export verses data from database."""
    if not db_path.exists():
        raise FileNotFoundError(f"Database not found: {db_path}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT b.shortname, v.chapter_id, v.verse_id, v.text
            FROM verses v
            JOIN books b ON b._id = v.book_id
            ORDER BY b.shortname, v.chapter_id, v.verse_id
        """)
        
        verses = []
        for row in cursor.fetchall():
            verses.append({
                "shortname": row[0],
                "chapter_id": row[1],
                "verse_id": row[2],
                "text": row[3]
            })
        
        return verses
    
    finally:
        conn.close()

def write_json_file(data: list[dict], output_path: Path) -> None:
    """Write data to JSON file."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"Exported {len(data)} items to {output_path}")

def main():
    """Main export function."""
    print("Exporting Bible data to JSON files...")
    
    # Check if databases exist
    for db_path in [RSVCE_DB, NABRE_DB]:
        if not db_path.exists():
            print(f"Warning: Database not found: {db_path}")
    
    # Export books (same for all versions, use RSVCE as source)
    if RSVCE_DB.exists():
        print("Exporting books...")
        books = export_books_from_db(RSVCE_DB)
        write_json_file(books, BOOKS_JSON)
    
    # Export verses for each version
    versions = [
        ("RSVCE", RSVCE_DB, VERSES_RSVCE_JSON),
        ("NABRE", NABRE_DB, VERSES_NABRE_JSON),
    ]
    
    for version_name, db_path, output_path in versions:
        if db_path.exists():
            print(f"Exporting {version_name} verses...")
            verses = export_verses_from_db(db_path)
            write_json_file(verses, output_path)
        else:
            print(f"Skipping {version_name} - database not found")
    
    print("Export complete!")
    print("\nGenerated files:")
    print(f"  - {BOOKS_JSON}")
    print(f"  - {VERSES_RSVCE_JSON}")
    print(f"  - {VERSES_NABRE_JSON}")

if __name__ == "__main__":
    main()
