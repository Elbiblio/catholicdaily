#!/usr/bin/env python3
"""
Fix psalm response partial verse notation in readings.db
Updates entries like "Ps 145:8" to "Ps 145:8a" where appropriate
"""

import sqlite3
import sys
from pathlib import Path

# Known psalm response corrections (date -> correct reference)
PSALM_RESPONSE_FIXES = {
    '2026-03-18': 'Ps 145:8a',  # Should be 8a, not just 8
    # Add more as discovered
}

def fix_psalm_responses(db_path: str, dry_run: bool = False):
    """Fix psalm response partial verse notation"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print(f"{'DRY RUN: ' if dry_run else ''}Fixing psalm response partial verse notation...")
    
    fixes_applied = 0
    
    for date_str, correct_ref in PSALM_RESPONSE_FIXES.items():
        # Parse date
        year, month, day = map(int, date_str.split('-'))
        from datetime import datetime
        date = datetime(year, month, day, 8, 0, 0)
        timestamp = int(date.timestamp())
        
        # Find the responsorial psalm reading for this date
        cursor.execute('''
            SELECT rowid, reading, psalm_response 
            FROM readings 
            WHERE timestamp = ? AND position = 2
        ''', (timestamp,))
        
        row = cursor.fetchone()
        if not row:
            print(f"  ⚠ No psalm reading found for {date_str}")
            continue
        
        rowid, reading, current_response = row
        
        if current_response == correct_ref:
            print(f"  ✓ {date_str}: Already correct ({correct_ref})")
            continue
        
        print(f"  → {date_str}: {current_response} → {correct_ref}")
        
        if not dry_run:
            cursor.execute('''
                UPDATE readings 
                SET psalm_response = ? 
                WHERE rowid = ?
            ''', (correct_ref, rowid))
            fixes_applied += 1
    
    if not dry_run and fixes_applied > 0:
        conn.commit()
        print(f"\n✓ Applied {fixes_applied} fixes")
    elif dry_run:
        print(f"\nDRY RUN: Would apply {len(PSALM_RESPONSE_FIXES)} fixes")
    else:
        print(f"\nNo fixes needed")
    
    conn.close()

if __name__ == '__main__':
    db_path = Path(__file__).parent.parent / 'assets' / 'readings.db'
    
    if not db_path.exists():
        print(f"Error: Database not found at {db_path}")
        sys.exit(1)
    
    # Run dry run first
    print("=" * 60)
    fix_psalm_responses(str(db_path), dry_run=True)
    print("=" * 60)
    
    # Ask for confirmation
    response = input("\nApply these fixes? (yes/no): ")
    if response.lower() in ['yes', 'y']:
        fix_psalm_responses(str(db_path), dry_run=False)
        print("\n✓ Done!")
    else:
        print("\nCancelled.")
