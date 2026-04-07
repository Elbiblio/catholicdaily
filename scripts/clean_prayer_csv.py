#!/usr/bin/env python3
"""Clean and consolidate Prayer of the Faithful CSV"""

import csv
from pathlib import Path

input_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967_comprehensive.csv')
output_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967_cleaned.csv')

with open(input_path, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

# Filter out fragmentary entries and consolidate appendix
cleaned_rows = []
appendix_petitions = []

for row in rows:
    occasion = row['occasion']
    
    # Clean up OCR errors
    occasion = occasion.replace('TELE INVITATION', 'THE INVITATION')
    occasion = occasion.replace('TEE INVITATION', 'THE INVITATION')
    
    # Extract just the title if it includes the full content
    # Look for "THE INVITATION" and take everything before it
    if 'THE INVITATION' in occasion:
        occasion = occasion.split('THE INVITATION')[0].strip()
    
    # Skip fragmentary entries (those that start with "Let us commend", "Iet us commend", etc.)
    if occasion.startswith(('Let us commend', 'Iet us commend', 'Celebrant', 'THE PETITIONS')):
        # These are continuations, skip them
        continue
    
    # Skip entries that are just numbers or very short
    if len(occasion) < 5 or occasion.isdigit():
        continue
    
    # Skip entries that look like petition continuations (start with "2.", "3.", etc.)
    if occasion.startswith(('2.', '3.', '4.', '5.', 'Into thy hands')):
        continue
    
    # Handle appendix entries - collect them separately (pages 102-109)
    page_num = int(row['page_number']) if row['page_number'].isdigit() else 0
    if 102 <= page_num <= 109:
        appendix_petitions.append(row['petitions'])
        continue
    
    # Keep all other entries
    cleaned_rows.append(row)

# Create a single appendix entry if we collected any
if appendix_petitions:
    all_appendix = ' | '.join(appendix_petitions)
    cleaned_rows.append({
        'page_number': '102-109',
        'occasion': 'APPENDIX - Categorized Petitions',
        'petitions': all_appendix
    })

# Write cleaned CSV
with open(output_path, 'w', encoding='utf-8', newline='') as f:
    fieldnames = ['page_number', 'occasion', 'petitions']
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(cleaned_rows)

print(f'Original entries: {len(rows)}')
print(f'Cleaned entries: {len(cleaned_rows)}')
print(f'Appendix petitions consolidated: {len(appendix_petitions)} items')
print(f'Output: {output_path}')
