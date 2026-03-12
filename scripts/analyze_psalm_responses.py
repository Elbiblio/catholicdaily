#!/usr/bin/env python3
"""
Analyze psalm responses in readings.db to identify entries missing partial verse notation
"""

import sqlite3
import re
from pathlib import Path
from datetime import datetime

def analyze_psalm_responses(db_path: str):
    """Analyze all psalm responses to find those missing partial verse notation"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("=" * 80)
    print("PSALM RESPONSE ANALYSIS")
    print("=" * 80)
    
    # Get all psalm responses
    cursor.execute('''
        SELECT rowid, timestamp, reading, psalm_response 
        FROM readings 
        WHERE position = 2 
        AND psalm_response IS NOT NULL 
        AND psalm_response != ''
        ORDER BY timestamp
    ''')
    
    rows = cursor.fetchall()
    print(f"\nTotal psalm readings with responses: {len(rows)}")
    
    # Categorize responses
    verse_refs = []  # Like "Ps 145:8" (might need part letter)
    already_with_parts = []  # Like "Ps 145:8a"
    plain_text = []  # Already decoded text
    
    for rowid, timestamp, reading, response in rows:
        date = datetime.fromtimestamp(timestamp)
        date_str = date.strftime('%Y-%m-%d')
        
        # Check if it's a verse reference
        if re.match(r'^(?:Ps|Psalm)\s*\.?\s*\d+:\d+[a-d]?$', response.strip(), re.IGNORECASE):
            # Check if it already has a part letter
            if re.search(r'\d+[a-d]$', response.strip()):
                already_with_parts.append((rowid, date_str, reading, response))
            else:
                verse_refs.append((rowid, date_str, reading, response))
        else:
            plain_text.append((rowid, date_str, reading, response[:50]))
    
    print(f"\n📊 BREAKDOWN:")
    print(f"  - Verse references without part letters: {len(verse_refs)}")
    print(f"  - Verse references with part letters: {len(already_with_parts)}")
    print(f"  - Plain text responses: {len(plain_text)}")
    
    if verse_refs:
        print(f"\n⚠️  ENTRIES NEEDING REVIEW ({len(verse_refs)} total):")
        print("-" * 80)
        for rowid, date_str, reading, response in verse_refs[:20]:  # Show first 20
            print(f"  {date_str} | {reading:30s} | {response}")
        if len(verse_refs) > 20:
            print(f"  ... and {len(verse_refs) - 20} more entries")
    
    if already_with_parts:
        print(f"\n✓ SAMPLE ENTRIES WITH PART LETTERS ({len(already_with_parts)} total):")
        print("-" * 80)
        for rowid, date_str, reading, response in already_with_parts[:5]:
            print(f"  {date_str} | {reading:30s} | {response}")
    
    if plain_text:
        print(f"\n✓ SAMPLE PLAIN TEXT RESPONSES ({len(plain_text)} total):")
        print("-" * 80)
        for rowid, date_str, reading, response in plain_text[:5]:
            print(f"  {date_str} | {reading:30s} | {response}...")
    
    conn.close()
    
    return verse_refs

if __name__ == '__main__':
    db_path = Path(__file__).parent.parent / 'assets' / 'readings.db'
    
    if not db_path.exists():
        print(f"Error: Database not found at {db_path}")
        exit(1)
    
    needs_review = analyze_psalm_responses(str(db_path))
    
    print("\n" + "=" * 80)
    print(f"SUMMARY: {len(needs_review)} entries may need partial verse notation")
    print("=" * 80)
