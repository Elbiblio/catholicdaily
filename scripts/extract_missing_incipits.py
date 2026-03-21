#!/usr/bin/env python3
"""
Script to extract missing incipits from CSV files using script sources.

This script:
1. Reads standard_lectionary_complete.csv and memorial_feasts.csv
2. Identifies rows with empty incipits
3. Attempts to extract incipits from script files (weekday_a_full.txt, weekday_b_full.txt, sunday_readings_columns.txt)
4. Documents findings in empty_incipit_findings.csv
"""

import csv
import re
from pathlib import Path
from typing import Dict, List, Tuple, Optional

def load_csv_file(filepath: Path) -> List[Dict]:
    """Load CSV file and return list of dictionaries."""
    data = []
    try:
        with open(filepath, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            for row in reader:
                data.append(row)
        print(f"Loaded {len(data)} rows from {filepath.name}")
        return data
    except Exception as e:
        print(f"Error loading {filepath}: {e}")
        return []

def load_script_file(filepath: Path) -> Dict[str, Dict]:
    """
    Load script file and create lookup dictionary.
    
    Returns dict with reference as key, containing text and any found incipit.
    """
    script_data = {}
    try:
        with open(filepath, 'r', encoding='utf-8') as file:
            content = file.read()
        
        # Split into reading sections by looking for patterns like "FIRST READING Genesis 1.1-19"
        # or "A reading from the book of Genesis."
        sections = re.split(r'\n(?=[A-Z]+ READING|A reading from the holy gospel)', content)
        
        for section in sections:
            section = section.strip()
            if not section or len(section) < 50:  # Skip very short sections
                continue
            
            # Extract book and reference from headers
            reference = extract_reference_from_section(section)
            if reference:
                # Extract the actual biblical text (lines starting with verse numbers)
                biblical_text = extract_biblical_text_from_section(section)
                if biblical_text:
                    script_data[reference] = {
                        'text': biblical_text,
                        'incipit': extract_incipit_from_text(biblical_text)
                    }
        
        print(f"Loaded {len(script_data)} references from {filepath.name}")
        return script_data
        
    except Exception as e:
        print(f"Error loading {filepath}: {e}")
        return {}

def extract_reference_from_section(section: str) -> Optional[str]:
    """Extract biblical reference from section header."""
    lines = section.split('\n')
    
    for line in lines:
        line = line.strip()
        
        # Look for patterns like "SECOND READING Acts 13.22-26" or "FIRST READING Genesis 1.1-19"
        reading_match = re.match(r'^[A-Z]+ READING\s+([A-Za-z]{1,5})\s+(\d+)[\.\-](\d+)(?:[\.\-](\d+))?', line)
        if reading_match:
            book = reading_match.group(1)
            chapter = reading_match.group(2)
            verse_start = reading_match.group(3)
            verse_end = reading_match.group(4) if reading_match.group(4) else verse_start
            
            # Format as standard reference with colon instead of dot
            return f"{book} {chapter}:{verse_start}{f'-{verse_end}' if verse_end != verse_start else ''}"
        
        # Look for patterns in gospel headers
        gospel_match = re.search(r'gospel according to ([A-Za-z]{1,5})', line, re.IGNORECASE)
        if gospel_match:
            # For gospels, we need to find the verse numbers in the text
            book = gospel_match.group(1)
            verse_match = re.search(r'[^\d](\d+)[\.\-](\d+)', section)  # Look for verse patterns
            if verse_match:
                chapter = verse_match.group(1)
                verse_end = verse_match.group(2) if verse_match.group(2) else None
                return f"{book} {chapter}:{verse_end or '1'}"
    
    return None

def extract_biblical_text_from_section(section: str) -> str:
    """Extract the actual biblical text from a section."""
    lines = section.split('\n')
    biblical_lines = []
    
    for line in lines:
        line = line.strip()
        
        # Skip headers and non-biblical content
        if (re.match(r'^[A-Z]+ READING', line) or 
            re.match(r'^A reading from', line) or 
            re.match(r'^The word became flesh', line) or
            re.match(r'^@$', line) or
            not line):
            continue
        
        # Include lines that start with verse numbers or seem to be biblical text
        if (re.match(r'^\d+', line) or 
            biblical_lines or  # If we've started collecting biblical text
            re.search(r'[A-Za-z]', line)):  # Contains letters
            biblical_lines.append(line)
    
    return '\n'.join(biblical_lines)

def extract_incipit_from_text(text: str) -> Optional[str]:
    """
    Extract incipit from biblical text.
    
    Looks for common incipit patterns at the beginning of text.
    """
    lines = text.split('\n')
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        # Skip verse numbers at the beginning
        verse_match = re.match(r'^(\d+)[a-z]?[\.\-]\s*(.+)', line)
        if verse_match:
            line = verse_match.group(2).strip()
        
        # Common incipit patterns
        incipit_patterns = [
            r'^(In the beginning|In those days|At that time|Thus says the LORD|The LORD said|The LORD spoke|Brethren|Beloved|My son|Jesus said|Jesus spoke|Peter said|Paul said|Job answered|The beloved says|Wisdom has been given|I said to myself|Hear my children|The word of the LORD came|Hear the word of the LORD|I John saw|In that time|On that day|Now|Then|And|But|So|For|Therefore|However)[,:]\s*(.+)',
            r'^(He|She|They|It)\s+(.+)',  # Pronoun starts
            r'^([A-Z][a-z]+\s+[a-z]+)\s+(.+)',  # Proper name + verb
        ]
        
        for pattern in incipit_patterns:
            match = re.match(pattern, line, re.IGNORECASE)
            if match:
                # Reconstruct with proper capitalization
                prefix = match.group(1).lower()
                if prefix in ['in the beginning', 'in those days', 'at that time', 'thus says the lord']:
                    return f"{match.group(1).capitalize()},"
                elif ':' in match.group(0):
                    return f"{match.group(1).capitalize()}:"
                else:
                    return f"{match.group(1).capitalize()}"
        
        # If no pattern matches, use first meaningful phrase
        if len(line) > 5:
            # Find first sentence or clause
            if '.' in line:
                first_sentence = line.split('.')[0].strip()
                if len(first_sentence) > 5:
                    return f"{first_sentence}."
            elif ',' in line:
                first_clause = line.split(',')[0].strip()
                if len(first_clause) > 5:
                    return f"{first_clause},"
            else:
                # Use the line as is if it's meaningful
                return line
    
    return None

def find_missing_incipits(
    lectionary_data: List[Dict], 
    memorial_data: List[Dict],
    script_sources: Dict[str, Dict[str, Dict]]
) -> List[Dict]:
    """Find rows with missing incipits and attempt to extract from scripts."""
    findings = []
    
    # Process lectionary data - check first_reading and gospel incipits
    for row in lectionary_data:
        season = row.get('season', '').strip()
        week = row.get('week', '').strip()
        day = row.get('day', '').strip()
        
        # Check first reading incipit
        first_reading = row.get('first_reading', '').strip()
        first_incipit = row.get('first_reading_incipit', '').strip()
        
        if first_reading and not first_incipit:
            finding = {
                'source_file': 'standard_lectionary_complete.csv',
                'reference': first_reading,
                'current_incipit': first_incipit,
                'extracted_incipit': None,
                'script_source': None,
                'cycle': f"{row.get('weekday_cycle', '')}/{row.get('sunday_cycle', '')}",
                'date': f"{season} {week} {day}",
                'reading_type': 'First Reading',
                'notes': ''
            }
            
            # Try to extract from script sources
            for script_name, script_data in script_sources.items():
                if first_reading in script_data:
                    finding['extracted_incipit'] = script_data[first_reading]['incipit']
                    finding['script_source'] = script_name
                    finding['notes'] = f"Incipit extracted from {script_name}"
                    break
            
            if not finding['extracted_incipit']:
                finding['notes'] = "No matching reference found in script sources"
            
            findings.append(finding)
        
        # Check gospel incipit
        gospel = row.get('gospel', '').strip()
        gospel_incipit = row.get('gospel_incipit', '').strip()
        
        if gospel and not gospel_incipit:
            finding = {
                'source_file': 'standard_lectionary_complete.csv',
                'reference': gospel,
                'current_incipit': gospel_incipit,
                'extracted_incipit': None,
                'script_source': None,
                'cycle': f"{row.get('weekday_cycle', '')}/{row.get('sunday_cycle', '')}",
                'date': f"{season} {week} {day}",
                'reading_type': 'Gospel',
                'notes': ''
            }
            
            # Try to extract from script sources
            for script_name, script_data in script_sources.items():
                if gospel in script_data:
                    finding['extracted_incipit'] = script_data[gospel]['incipit']
                    finding['script_source'] = script_name
                    finding['notes'] = f"Incipit extracted from {script_name}"
                    break
            
            if not finding['extracted_incipit']:
                finding['notes'] = "No matching reference found in script sources"
            
            findings.append(finding)
        
        # Check second reading incipit (if exists)
        second_reading = row.get('second_reading', '').strip()
        if second_reading:
            # Some CSVs might have second_reading_incipit column
            second_incipit = row.get('second_reading_incipit', '').strip()
            
            if not second_incipit:
                finding = {
                    'source_file': 'standard_lectionary_complete.csv',
                    'reference': second_reading,
                    'current_incipit': second_incipit,
                    'extracted_incipit': None,
                    'script_source': None,
                    'cycle': f"{row.get('weekday_cycle', '')}/{row.get('sunday_cycle', '')}",
                    'date': f"{season} {week} {day}",
                    'reading_type': 'Second Reading',
                    'notes': ''
                }
                
                # Try to extract from script sources
                for script_name, script_data in script_sources.items():
                    if second_reading in script_data:
                        finding['extracted_incipit'] = script_data[second_reading]['incipit']
                        finding['script_source'] = script_name
                        finding['notes'] = f"Incipit extracted from {script_name}"
                        break
                
                if not finding['extracted_incipit']:
                    finding['notes'] = "No matching reference found in script sources"
                
                findings.append(finding)
    
    # Process memorial data - check for different structure
    for row in memorial_data:
        # Memorial CSV might have different column structure
        reference = row.get('Reference', '').strip() or row.get('reference', '').strip()
        current_incipit = row.get('Incipit', '').strip() or row.get('incipit', '').strip()
        
        if reference and not current_incipit:
            finding = {
                'source_file': 'memorial_feasts.csv',
                'reference': reference,
                'current_incipit': current_incipit,
                'extracted_incipit': None,
                'script_source': None,
                'cycle': row.get('Cycle', ''),
                'date': row.get('Date', ''),
                'reading_type': row.get('Reading Type', ''),
                'notes': ''
            }
            
            # Try to extract from script sources
            for script_name, script_data in script_sources.items():
                if reference in script_data:
                    finding['extracted_incipit'] = script_data[reference]['incipit']
                    finding['script_source'] = script_name
                    finding['notes'] = f"Incipit extracted from {script_name}"
                    break
            
            if not finding['extracted_incipit']:
                finding['notes'] = "No matching reference found in script sources"
            
            findings.append(finding)
    
    return findings

def save_findings(findings: List[Dict], output_path: Path):
    """Save findings to CSV file."""
    fieldnames = [
        'source_file', 'reference', 'current_incipit', 'extracted_incipit',
        'script_source', 'cycle', 'date', 'reading_type', 'notes'
    ]
    
    with open(output_path, 'w', newline='', encoding='utf-8') as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(findings)
    
    print(f"Saved {len(findings)} findings to {output_path.name}")

def main():
    """Main execution function."""
    base_dir = Path(__file__).parent.parent
    
    # Input files
    lectionary_csv = base_dir / 'standard_lectionary_complete.csv'
    memorial_csv = base_dir / 'memorial_feasts.csv'
    
    # Script sources
    weekday_a_script = base_dir / 'scripts' / 'weekday_a_full.txt'
    weekday_b_script = base_dir / 'scripts' / 'weekday_b_full.txt'
    sunday_script = base_dir / 'scripts' / 'sunday_readings_columns.txt'
    
    # Output file
    output_file = base_dir / 'empty_incipit_findings.csv'
    
    print("=== Missing Incipit Extraction Script ===")
    print()
    
    # Load CSV files
    lectionary_data = load_csv_file(lectionary_csv)
    memorial_data = load_csv_file(memorial_csv)
    
    # Load script sources
    script_sources = {}
    
    if weekday_a_script.exists():
        script_sources['weekday_a_full.txt'] = load_script_file(weekday_a_script)
    
    if weekday_b_script.exists():
        script_sources['weekday_b_full.txt'] = load_script_file(weekday_b_script)
    
    if sunday_script.exists():
        script_sources['sunday_readings_columns.txt'] = load_script_file(sunday_script)
    
    print(f"\nLoaded {len(script_sources)} script sources")
    print()
    
    # Find missing incipits
    findings = find_missing_incipits(lectionary_data, memorial_data, script_sources)
    
    # Save findings
    save_findings(findings, output_file)
    
    # Print summary
    total_missing = len(findings)
    extracted_count = sum(1 for f in findings if f['extracted_incipit'])
    
    print(f"\n=== Summary ===")
    print(f"Total rows with missing incipits: {total_missing}")
    print(f"Incipits successfully extracted: {extracted_count}")
    print(f"Extraction success rate: {extracted_count/total_missing*100:.1f}%" if total_missing > 0 else "N/A")
    print(f"Results saved to: {output_file}")
    
    # Show sample of findings
    if findings:
        print(f"\n=== Sample Findings ===")
        for i, finding in enumerate(findings[:5]):
            print(f"{i+1}. {finding['reference']} ({finding['source_file']})")
            print(f"   Current: '{finding['current_incipit']}'")
            print(f"   Extracted: '{finding['extracted_incipit']}'")
            print(f"   Source: {finding['script_source']}")
            print(f"   Notes: {finding['notes']}")
            print()

if __name__ == "__main__":
    main()
