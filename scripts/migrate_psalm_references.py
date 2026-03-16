#!/usr/bin/env python3
"""
Migrate responsorial psalm references in readings.db using resolved mappings.

This script applies the corrections from the resolution script to update
the database with correct psalm references and responses.
"""

import sqlite3
import json
import shutil
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

class PsalmReferenceMigrator:
    """Migrates psalm references in the database."""
    
    def __init__(self, db_path: str, mapping_file: str):
        self.db_path = Path(db_path)
        self.mapping_file = Path(mapping_file)
        self.backup_dir = Path(__file__).parent.parent / 'backups'
        
    def create_backup(self) -> Path:
        """Create a timestamped backup of the database."""
        self.backup_dir.mkdir(exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_path = self.backup_dir / f'readings.db.backup.{timestamp}'
        
        print(f"Creating backup: {backup_path}")
        shutil.copy2(self.db_path, backup_path)
        
        # Keep only last 5 backups
        backups = sorted(self.backup_dir.glob('readings.db.backup.*'))
        if len(backups) > 5:
            for old_backup in backups[:-5]:
                old_backup.unlink()
                print(f"Removed old backup: {old_backup}")
        
        return backup_path
    
    def load_mappings(self) -> List[Dict]:
        """Load psalm reference mappings from JSON file."""
        with open(self.mapping_file, 'r') as f:
            data = json.load(f)
        
        print(f"Loaded {data['metadata']['total_resolved']} mappings")
        print(f"Confidence threshold: {data['metadata']['confidence_threshold']}")
        print(f"Generated: {data['metadata']['generated_at']}")
        
        return data['resolutions']
    
    def apply_migrations(self, mappings: List[Dict], dry_run: bool = False) -> Dict:
        """Apply migrations to the database."""
        results = {
            'total': len(mappings),
            'applied': 0,
            'skipped': 0,
            'errors': 0,
            'details': []
        }
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            for mapping in mappings:
                rowid = mapping['rowid']
                old_ref = mapping['old_reference']
                new_ref = mapping['new_reference']
                response = mapping['response']
                date = mapping['date']
                confidence = mapping['confidence']
                method = mapping['method']
                
                # Verify current state
                cursor.execute(
                    "SELECT reading, psalm_response FROM readings WHERE rowid = ?",
                    (rowid,)
                )
                current = cursor.fetchone()
                
                if not current:
                    results['errors'] += 1
                    results['details'].append(f"Row {rowid}: Not found")
                    continue
                
                current_ref, current_response = current
                
                # Check if reference matches expected
                if current_ref != old_ref:
                    results['skipped'] += 1
                    results['details'].append(
                        f"Row {rowid} ({date}): Reference mismatch. "
                        f"Expected '{old_ref}', found '{current_ref}'"
                    )
                    continue
                
                # Fix new reference format if needed (add Ps prefix if missing)
                if not new_ref.startswith('Ps '):
                    chapter_match = re.match(r'Ps\s+(\d+):', old_ref)
                    if chapter_match:
                        chapter = chapter_match.group(1)
                        new_ref = f"Ps {chapter}:{new_ref}"
                
                if dry_run:
                    results['applied'] += 1
                    results['details'].append(
                        f"Row {rowid} ({date}): Would update '{old_ref}' → '{new_ref}' "
                        f"(confidence: {confidence:.2f}, method: {method})"
                    )
                else:
                    # Apply update
                    cursor.execute(
                        "UPDATE readings SET reading = ?, psalm_response = ? WHERE rowid = ?",
                        (new_ref, response, rowid)
                    )
                    
                    results['applied'] += 1
                    results['details'].append(
                        f"Row {rowid} ({date}): Updated '{old_ref}' → '{new_ref}' "
                        f"(confidence: {confidence:.2f}, method: {method})"
                    )
            
            if not dry_run:
                conn.commit()
                print(f"Committed {results['applied']} changes to database")
            
        except Exception as e:
            conn.rollback()
            results['errors'] += 1
            results['details'].append(f"Database error: {str(e)}")
            raise
        finally:
            conn.close()
        
        return results
    
    def verify_migrations(self, mappings: List[Dict]) -> Dict:
        """Verify that migrations were applied correctly."""
        results = {
            'verified': 0,
            'failed': 0,
            'details': []
        }
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            for mapping in mappings:
                rowid = mapping['rowid']
                expected_ref = mapping['new_reference']
                expected_response = mapping['response']
                date = mapping['date']
                
                cursor.execute(
                    "SELECT reading, psalm_response FROM readings WHERE rowid = ?",
                    (rowid,)
                )
                current = cursor.fetchone()
                
                if not current:
                    results['failed'] += 1
                    results['details'].append(f"Row {rowid} ({date}): Not found after migration")
                    continue
                
                current_ref, current_response = current
                
                # Fix expected reference format for comparison
                if not expected_ref.startswith('Ps '):
                    chapter_match = re.match(r'Ps\s+(\d+):', mapping['old_reference'])
                    if chapter_match:
                        chapter = chapter_match.group(1)
                        expected_ref = f"Ps {chapter}:{expected_ref}"
                
                if current_ref == expected_ref and current_response == expected_response:
                    results['verified'] += 1
                else:
                    results['failed'] += 1
                    results['details'].append(
                        f"Row {rowid} ({date}): Verification failed. "
                        f"Ref: expected '{expected_ref}', found '{current_ref}'. "
                        f"Response: expected '{expected_response[:30]}...', found '{current_response[:30]}...'"
                    )
        
        finally:
            conn.close()
        
        return results
    
    def filter_by_date(self, mappings: List[Dict], start_year: int = 2025) -> List[Dict]:
        """Filter mappings to only include entries from specified year onwards."""
        filtered = []
        for mapping in mappings:
            date = mapping['date']
            year = int(date.split('-')[0])
            if year >= start_year:
                filtered.append(mapping)
        
        print(f"Filtered to {len(filtered)} entries from {start_year} onwards")
        return filtered

def main():
    print(
        "This legacy psalm reference migrator is retired. "
        "Migrate psalm references in the CSV catalogs instead of readings.db."
    )
    return 1

if __name__ == '__main__':
    exit(main())
