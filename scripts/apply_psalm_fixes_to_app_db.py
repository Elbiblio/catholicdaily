#!/usr/bin/env python3
"""
Apply psalm reference fixes to the app's database before deployment.

This script reads the resolutions from the migration and applies them
to the app's database file, creating a production-ready database
with all the corrections.
"""

import sqlite3
import json
import shutil
from pathlib import Path
from datetime import datetime

def apply_fixes_to_database(db_path: str, resolutions_file: str, output_path: str = None):
    """
    Apply psalm reference fixes to a database file.
    
    Args:
        db_path: Path to the source database (assets/readings.db)
        resolutions_file: Path to the resolutions JSON file
        output_path: Where to save the fixed database (optional)
    """
    
    # Load resolutions
    with open(resolutions_file, 'r') as f:
        data = json.load(f)
    
    resolutions = data['resolutions']
    print(f"Loaded {len(resolutions)} resolutions from {data['metadata']['generated_at']}")
    
    # Copy database to working location
    db_source = Path(db_path)
    if output_path is None:
        output_path = db_source.parent / f'readings_fixed_{datetime.now().strftime("%Y%m%d_%H%M%S")}.db'
    
    print(f"Copying database from {db_source} to {output_path}")
    shutil.copy2(db_source, output_path)
    
    # Apply fixes
    conn = sqlite3.connect(output_path)
    cursor = conn.cursor()
    
    applied = 0
    skipped = 0
    errors = 0
    
    try:
        for resolution in resolutions:
            rowid = resolution['rowid']
            old_ref = resolution['old_reference']
            new_ref = resolution['new_reference']
            response = resolution['response']
            date = resolution['date']
            confidence = resolution['confidence']
            
            # Verify current state
            cursor.execute(
                "SELECT reading, psalm_response FROM readings WHERE rowid = ?",
                (rowid,)
            )
            current = cursor.fetchone()
            
            if not current:
                errors += 1
                print(f"  ERROR: Row {rowid} not found")
                continue
            
            current_ref, current_response = current
            
            # Check if reference matches expected
            if current_ref != old_ref:
                skipped += 1
                print(f"  SKIP: Row {rowid} ({date}): Reference mismatch")
                print(f"        Expected: {old_ref}")
                print(f"        Found: {current_ref}")
                continue
            
            # Fix new reference format if needed
            if not new_ref.startswith('Ps '):
                import re
                chapter_match = re.match(r'Ps\s+(\d+):', old_ref)
                if chapter_match:
                    chapter = chapter_match.group(1)
                    new_ref = f"Ps {chapter}:{new_ref}"
            
            # Apply update
            cursor.execute(
                "UPDATE readings SET reading = ?, psalm_response = ? WHERE rowid = ?",
                (new_ref, response, rowid)
            )
            
            applied += 1
            if applied <= 10:  # Show first 10 updates
                print(f"  FIXED: Row {rowid} ({date}): {old_ref} → {new_ref}")
                print(f"         Response: {response[:50]}...")
            elif applied == 11:
                print(f"  ... and {len(resolutions) - 10} more fixes")
        
        conn.commit()
        print(f"\nSuccessfully applied {applied} fixes")
        print(f"Skipped: {skipped}")
        print(f"Errors: {errors}")
        
        # Verification
        print("\nVerifying fixes...")
        verified = 0
        failed = 0
        
        for resolution in resolutions[:20]:  # Verify first 20
            rowid = resolution['rowid']
            expected_ref = resolution['new_reference']
            expected_response = resolution['response']
            
            cursor.execute(
                "SELECT reading, psalm_response FROM readings WHERE rowid = ?",
                (rowid,)
            )
            current = cursor.fetchone()
            
            if current and current[0] == expected_ref and current[1] == expected_response:
                verified += 1
            else:
                failed += 1
                print(f"  VERIFY FAIL: Row {rowid}")
        
        print(f"Verification: {verified} verified, {failed} failed (sample of 20)")
        
        # Create final production database
        final_path = db_source.parent / 'readings.db'
        print(f"\nCreating production database at {final_path}")
        shutil.copy2(output_path, final_path)
        
        print(f"\n✅ Production database updated successfully!")
        print(f"   Source: {db_source}")
        print(f"   Fixed: {output_path}")
        print(f"   Production: {final_path}")
        
    except Exception as e:
        conn.rollback()
        print(f"Error applying fixes: {e}")
        raise
    finally:
        conn.close()

def main():
    """Main entry point."""
    print(
        "This legacy psalm DB fix applicator is retired. "
        "Apply psalm fixes to the CSV catalogs instead of producing a patched readings.db."
    )
    return 1

if __name__ == '__main__':
    exit(main())
