#!/usr/bin/env python3
import csv
import re
from pathlib import Path

def extract_script_references(filepath: Path):
    """Extract references from script file."""
    references = set()
    
    with open(filepath, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Find all reading patterns
    sections = re.split(r'\n(?=[A-Z]+ READING|A reading from the holy gospel)', content)
    
    for section in sections:
        section = section.strip()
        if not section or len(section) < 50:
            continue
        
        # Extract reference from header
        lines = section.split('\n')
        for line in lines:
            line = line.strip()
            reading_match = re.match(r'^[A-Z]+ READING\s+([A-Za-z]{1,5})\s+(\d+)[\.\-](\d+)(?:[\.\-](\d+))?', line)
            if reading_match:
                book = reading_match.group(1)
                chapter = reading_match.group(2)
                verse_start = reading_match.group(3)
                verse_end = reading_match.group(4) if reading_match.group(4) else verse_start
                
                # Format as standard reference with colon
                ref = f"{book} {chapter}:{verse_start}{f'-{verse_end}' if verse_end != verse_start else ''}"
                references.add(ref)
                break
    
    return references

def main():
    base_dir = Path(__file__).parent
    
    # Load script references
    script_refs = set()
    script_files = [
        base_dir / 'scripts' / 'weekday_a_full.txt',
        base_dir / 'scripts' / 'weekday_b_full.txt', 
        base_dir / 'scripts' / 'sunday_readings_columns.txt'
    ]
    
    for script_file in script_files:
        if script_file.exists():
            refs = extract_script_references(script_file)
            script_refs.update(refs)
            print(f"Loaded {len(refs)} references from {script_file.name}")
    
    # Check missing incipits from CSV
    missing_refs = []
    with open(base_dir / 'empty_incipit_findings.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        for row in reader:
            if row['reference'] and not row['extracted_incipit']:
                missing_refs.append(row['reference'])
    
    print(f"\nChecking {len(missing_refs)} missing references...")
    
    # Find matches
    matches = []
    for ref in missing_refs:
        if ref in script_refs:
            matches.append(ref)
    
    print(f"\nFound {len(matches)} matches that should have been extracted:")
    for match in matches[:10]:  # Show first 10
        print(f"  {match}")
    
    # Show some near misses
    print(f"\nNear misses (same book, different verses):")
    for ref in missing_refs[:20]:  # Check first 20
        book = ref.split()[0]
        script_book_refs = [r for r in script_refs if r.startswith(book)]
        if script_book_refs:
            print(f"  {ref} - script has: {script_book_refs[:3]}")

if __name__ == "__main__":
    main()
