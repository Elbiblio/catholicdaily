#!/usr/bin/env python3
"""Parse extracted Spanish CPL prayer texts into CSV format"""

import re
from pathlib import Path

script_dir = Path(r'c:\dev\catholicdaily-flutter\scripts')
txt_files = [
    'cpl_prayer_faithful_2026-04-12.txt',
    'cpl_prayer_faithful_2026-04-19.txt',
    'cpl_prayer_faithful_2026-04-26.txt'
]

output_path = script_dir / 'cpl_prayer_faithful_spanish.csv'

csv_lines = []
csv_lines.append('date,liturgical_reference,year,response,petitions,concluding_prayer\n')

for txt_file in txt_files:
    txt_path = script_dir / txt_file
    
    with open(txt_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract date and liturgical reference from header
    header_match = re.search(r'(\d+ DE \w+ DE \d+)\s*\|\s*(.+?)(?:\n|$)', content)
    if header_match:
        date = header_match.group(1)
        liturgical_ref = header_match.group(2)
    else:
        continue
    
    # Extract year (e.g., "A" from "DOMINGO 2 DE PASCUA / A")
    year_match = re.search(r'/\s*([ABC])', liturgical_ref)
    year = year_match.group(1) if year_match else ''
    
    # Extract response (e.g., "JESÚS RESUCITADO, ESCÚCHANOS")
    response_match = re.search(r'diciendo:\s*(.+?)\n', content)
    response = response_match.group(1).strip() if response_match else ''
    
    # Extract petitions (lines starting with "Por" and ending with "OREMOS")
    petitions = []
    petition_pattern = re.compile(r'(Por\s+.+?)OREMOS', re.DOTALL)
    for match in petition_pattern.finditer(content):
        petition = match.group(1).strip()
        # Clean up whitespace
        petition = re.sub(r'\s+', ' ', petition)
        if petition:
            petitions.append(petition)
    
    # Extract concluding prayer (starts with "Escucha, Señor")
    concluding_match = re.search(r'(Escucha, Señor.+)', content)
    concluding = concluding_match.group(1).strip() if concluding_match else ''
    
    # Join petitions with pipe separator
    petitions_text = ' | '.join(petitions)
    
    # Add to CSV
    csv_lines.append(f'"{date}","{liturgical_ref}","{year}","{response}","{petitions_text}","{concluding}"\n')

with open(output_path, 'w', encoding='utf-8') as f:
    f.writelines(csv_lines)

print(f"Parsed {len(txt_files)} entries to {output_path}")
