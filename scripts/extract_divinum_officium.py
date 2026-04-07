#!/usr/bin/env python3
"""
Extract Divinum Officium propers to CSV format for variable rites.

This script parses Divinum Officium text files and extracts:
- Collect (Oratio)
- Prayer over Offerings (Secreta)
- Communion Antiphon (Communio)
- Prayer after Communion (Postcommunio)

Output: CSV with season/week/day/feast context and the extracted prayers.
"""

import os
import re
import csv
from pathlib import Path
from typing import Dict, List, Optional

# Directory structure
DIVINUM_OFFICIUM_PATH = "temp_divinum_officium/web/www/missa/English"
OUTPUT_CSV = "scripts/divinum_officium_propers_english.csv"


def parse_file(filepath: Path) -> Dict[str, str]:
    """
    Parse a Divinum Officium text file and extract propers.
    
    Returns dict with keys: title, collect, secret, communion, postcommunion
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    result = {
        'title': '',
        'collect': '',
        'secret': '',
        'communion': '',
        'postcommunion': '',
    }
    
    # Extract title from [Officium] or [Rank] section
    officium_match = re.search(r'\[Officium\]\s*(.+?)(?:\n|$)', content)
    if officium_match:
        result['title'] = officium_match.group(1).strip()
    
    # Extract [Oratio] (Collect)
    oratio_match = re.search(r'\[Oratio\]\s*(.+?)(?:\[|\$)', content, re.DOTALL)
    if oratio_match:
        result['collect'] = oratio_match.group(1).strip()
    
    # Extract [Secreta] (Prayer over Offerings)
    secreta_match = re.search(r'\[Secreta\]\s*(.+?)(?:\[|\$)', content, re.DOTALL)
    if secreta_match:
        result['secret'] = secreta_match.group(1).strip()
    
    # Extract [Communio] (Communion Antiphon)
    communio_match = re.search(r'\[Communio\]\s*(.+?)(?:\[|\$)', content, re.DOTALL)
    if communio_match:
        result['communion'] = communio_match.group(1).strip()
    
    # Extract [Postcommunio] (Prayer after Communion)
    postcommunio_match = re.search(r'\[Postcommunio\]\s*(.+?)(?:\[|\$)', content, re.DOTALL)
    if postcommunio_match:
        result['postcommunion'] = postcommunio_match.group(1).strip()
    
    return result


def parse_filename(filename: str) -> Dict[str, str]:
    """
    Parse Divinum Officium filename to extract liturgical context.
    
    Tempora Examples:
    - Adv1-0.txt -> Advent Week 1 Sunday
    - Pent02-3.txt -> Pentecost Week 2 Wednesday
    - Quad1-0.txt -> Lent Week 1 Sunday
    
    Sancti Examples:
    - 01-01.txt -> January 1 (Circumcision)
    - 12-25.txt -> December 25 (Nativity)
    """
    result = {
        'season': '',
        'week': '',
        'day': '',
        'feast': '',
        'rank': '',
        'color': '',
        'month': '',
        'day_of_month': '',
    }
    
    # Remove .txt extension
    name = filename.replace('.txt', '')
    
    # Check if it's a Sancti file (MM-DD format)
    if re.match(r'^\d{2}-\d{2}', name):
        match = re.match(r'^(\d{2})-(\d{2})', name)
        if match:
            result['month'] = match.group(1)
            result['day_of_month'] = match.group(2)
            result['season'] = 'Sancti'  # Feast day
            result['feast'] = f"{result['month']}-{result['day_of_month']}"
            result['day'] = 'Feast'
        return result
    
    # Parse season and week for Tempora files
    # Advent: Adv1-0, Adv2-1, etc.
    # Epiphany: Epi1-0, Epi2-1, etc.
    # Lent: Quad1-0, Quad2-1, etc. (Quad = Quadragesima)
    # Pentecost: Pent01-0, Pent02-1, etc.
    # Christmas: Nat1-0, Nat2-0, etc.
    # Easter: Pasc0-0, Pasc1-1, etc.
    
    season_map = {
        'Adv': 'Advent',
        'Epi': 'Epiphany',
        'Quad': 'Lent',
        'Quadp': 'Lent (Pre-Lent)',
        'Pent': 'Ordinary Time',
        'PentEpi': 'Epiphany (Post-Pentecost)',
        'Nat': 'Christmas',
        'Pasc': 'Easter',
    }
    
    for prefix, season_name in season_map.items():
        if name.startswith(prefix):
            result['season'] = season_name
            # Extract week number
            week_match = re.search(rf'{prefix}(\d+)', name)
            if week_match:
                result['week'] = week_match.group(1)
            break
    
    # Parse day (0=Sunday, 1=Monday, ..., 6=Saturday)
    day_match = re.search(r'-(\d+)', name)
    if day_match:
        day_num = int(day_match.group(1))
        days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
        if day_num < len(days):
            result['day'] = days[day_num]
    
    return result


def extract_from_directory(directory: Path) -> List[Dict[str, str]]:
    """
    Extract propers from all .txt files in a directory.
    """
    results = []
    
    for filepath in directory.glob('*.txt'):
        try:
            # Parse filename for context
            context = parse_filename(filepath.name)
            
            # Parse file for propers
            propers = parse_file(filepath)
            
            # Merge results
            row = {**context, **propers, 'source_file': filepath.name}
            results.append(row)
            
        except Exception as e:
            print(f"Error processing {filepath}: {e}")
    
    return results


def main():
    # Ensure output directory exists
    output_path = Path(OUTPUT_CSV)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Process Tempora (seasonal) directory
    tempora_path = Path(DIVINUM_OFFICIUM_PATH) / 'Tempora'
    if tempora_path.exists():
        print(f"Processing Tempora directory: {tempora_path}")
        tempora_results = extract_from_directory(tempora_path)
        print(f"Extracted {len(tempora_results)} entries from Tempora")
    else:
        print(f"Tempora directory not found: {tempora_path}")
        tempora_results = []
    
    # Process Sancti (saints) directory
    sancti_path = Path(DIVINUM_OFFICIUM_PATH) / 'Sancti'
    if sancti_path.exists():
        print(f"Processing Sancti directory: {sancti_path}")
        sancti_results = extract_from_directory(sancti_path)
        print(f"Extracted {len(sancti_results)} entries from Sancti")
    else:
        print(f"Sancti directory not found: {sancti_path}")
        sancti_results = []
    
    # Combine results
    all_results = tempora_results + sancti_results
    
    # Filter to only include entries with actual propers
    # (exclude empty entries and those with only references like @Tempora/...)
    filtered_results = []
    for row in all_results:
        has_proper = False
        for field in ['collect', 'secret', 'communion', 'postcommunion']:
            value = row.get(field, '').strip()
            # Check if it has content and is not just a reference
            if value and not value.startswith('@'):
                has_proper = True
                break
        if has_proper:
            filtered_results.append(row)
    
    print(f"Filtered to {len(filtered_results)} entries with actual propers (from {len(all_results)} total)")
    
    # Write to CSV
    csv_columns = [
        'season', 'week', 'day', 'feast', 'rank', 'color',
        'month', 'day_of_month',
        'title', 'collect', 'secret', 'communion', 'postcommunion',
        'source_file'
    ]
    
    with open(output_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=csv_columns)
        writer.writeheader()
        writer.writerows(filtered_results)
    
    print(f"\nTotal entries extracted: {len(filtered_results)}")
    print(f"Output written to: {output_path}")
    
    # Print sample entries
    if filtered_results:
        print("\nSample entry:")
        for key, value in filtered_results[0].items():
            print(f"  {key}: {value[:100] if len(str(value)) > 100 else value}")


if __name__ == '__main__':
    main()
