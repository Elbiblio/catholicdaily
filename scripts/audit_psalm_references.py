#!/usr/bin/env python3
"""
Audit responsorial psalm references in readings.db to identify problematic entries.

Problematic patterns:
- Long sequential ranges (e.g., "Ps 89:1-29" - 28 verses is too long for a responsorial psalm)
- Responsorial psalms rarely exceed 4 verses and rarely are sequential without commas
"""

import sqlite3
import re
from pathlib import Path
from datetime import datetime

def analyze_psalm_reference(reference):
    """
    Analyze a psalm reference to determine if it's problematic.
    
    Returns:
        dict: Analysis results with 'is_problematic', 'reason', and 'details'
    """
    # Extract psalm chapter and verse range
    match = re.match(r'Ps\s+(\d+):(.+)', reference, re.IGNORECASE)
    if not match:
        return {'is_problematic': False, 'reason': None, 'details': None}
    
    chapter = match.group(1)
    verse_part = match.group(2).strip()
    
    # Remove refrain notation if present
    verse_part = re.sub(r'\s*\(R\.\s*[^)]+\)', '', verse_part)
    
    # Check for simple long ranges (e.g., "1-29", "2-25")
    simple_range_match = re.match(r'^(\d+)-(\d+)$', verse_part)
    if simple_range_match:
        start = int(simple_range_match.group(1))
        end = int(simple_range_match.group(2))
        verse_count = end - start + 1
        
        if verse_count > 10:
            return {
                'is_problematic': True,
                'reason': 'long_sequential_range',
                'details': f'{verse_count} verses ({start}-{end})',
                'verse_count': verse_count
            }
    
    # Check for ranges without commas that span many verses
    if ',' not in verse_part and '-' in verse_part:
        # Try to extract all verse numbers
        verse_numbers = re.findall(r'\d+', verse_part)
        if len(verse_numbers) >= 2:
            try:
                start = int(verse_numbers[0])
                end = int(verse_numbers[-1])
                verse_count = end - start + 1
                
                if verse_count > 8:
                    return {
                        'is_problematic': True,
                        'reason': 'long_range_without_commas',
                        'details': f'{verse_count} verses ({start}-{end})',
                        'verse_count': verse_count
                    }
            except ValueError:
                pass
    
    # Check for suspiciously simple patterns (just chapter number, no verses)
    if not verse_part or verse_part.isspace():
        return {
            'is_problematic': True,
            'reason': 'missing_verse_specification',
            'details': 'No verse numbers specified'
        }
    
    return {'is_problematic': False, 'reason': None, 'details': None}

def audit_database(db_path):
    """
    Audit the readings.db for problematic psalm references.
    
    Args:
        db_path: Path to readings.db
        
    Returns:
        dict: Audit results with statistics and problematic entries
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Query all psalm readings
    cursor.execute("""
        SELECT rowid, reading, position, psalm_response, timestamp
        FROM readings
        WHERE position = 2
        ORDER BY rowid
    """)
    
    rows = cursor.fetchall()
    
    results = {
        'total_psalms': len(rows),
        'problematic_count': 0,
        'problematic_entries': [],
        'by_reason': {},
        'verse_count_distribution': {}
    }
    
    for row in rows:
        rowid, reading, position, psalm_response, timestamp = row
        
        analysis = analyze_psalm_reference(reading)
        
        if analysis['is_problematic']:
            results['problematic_count'] += 1
            
            # Convert timestamp to date
            date = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d')
            
            entry = {
                'rowid': rowid,
                'reference': reading,
                'date': date,
                'psalm_response': psalm_response,
                'reason': analysis['reason'],
                'details': analysis['details']
            }
            
            results['problematic_entries'].append(entry)
            
            # Track by reason
            reason = analysis['reason']
            if reason not in results['by_reason']:
                results['by_reason'][reason] = []
            results['by_reason'][reason].append(entry)
            
            # Track verse count distribution
            if 'verse_count' in analysis:
                count = analysis['verse_count']
                if count not in results['verse_count_distribution']:
                    results['verse_count_distribution'][count] = 0
                results['verse_count_distribution'][count] += 1
    
    conn.close()
    
    return results

def print_audit_report(results):
    """Print a formatted audit report."""
    print("=" * 80)
    print("RESPONSORIAL PSALM REFERENCE AUDIT REPORT")
    print("=" * 80)
    print()
    
    print(f"Total Psalm Readings: {results['total_psalms']}")
    print(f"Problematic Entries: {results['problematic_count']}")
    print(f"Percentage Problematic: {results['problematic_count'] / results['total_psalms'] * 100:.1f}%")
    print()
    
    if results['problematic_count'] > 0:
        print("-" * 80)
        print("BREAKDOWN BY REASON")
        print("-" * 80)
        for reason, entries in results['by_reason'].items():
            print(f"\n{reason.replace('_', ' ').title()}: {len(entries)} entries")
        
        print()
        print("-" * 80)
        print("VERSE COUNT DISTRIBUTION (for long ranges)")
        print("-" * 80)
        for count in sorted(results['verse_count_distribution'].keys(), reverse=True):
            freq = results['verse_count_distribution'][count]
            print(f"  {count} verses: {freq} occurrences")
        
        print()
        print("-" * 80)
        print("SAMPLE PROBLEMATIC ENTRIES (first 20)")
        print("-" * 80)
        print()
        
        for i, entry in enumerate(results['problematic_entries'][:20], 1):
            print(f"{i}. Row {entry['rowid']} - {entry['date']}")
            print(f"   Reference: {entry['reference']}")
            print(f"   Reason: {entry['reason'].replace('_', ' ')}")
            print(f"   Details: {entry['details']}")
            if entry['psalm_response']:
                print(f"   Response: {entry['psalm_response'][:60]}...")
            print()
        
        if len(results['problematic_entries']) > 20:
            print(f"... and {len(results['problematic_entries']) - 20} more problematic entries")
    
    print()
    print("=" * 80)

def main():
    """Main entry point."""
    # Find readings.db
    db_path = Path(__file__).parent.parent / 'assets' / 'readings.db'
    
    if not db_path.exists():
        print(f"Error: readings.db not found at {db_path}")
        return 1
    
    print(f"Auditing: {db_path}")
    print()
    
    results = audit_database(db_path)
    print_audit_report(results)
    
    # Save detailed results to JSON
    import json
    output_path = Path(__file__).parent.parent / 'psalm_audit_results.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    
    print(f"\nDetailed results saved to: {output_path}")
    
    return 0

if __name__ == '__main__':
    exit(main())
