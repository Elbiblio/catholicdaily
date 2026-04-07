#!/usr/bin/env python3
"""Parse extracted Prayer of the Faithful text into CSV format - comprehensive version"""

import re
from pathlib import Path

input_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967_extracted.txt')
output_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967_comprehensive.csv')

def parse_prayer_file(input_path, output_path):
    """Parse the extracted text into CSV format"""
    
    with open(input_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split by page markers
    pages = re.split(r'={80}\nFILE: EPUB/page_\d+\.html\n={80}\n', content)
    
    csv_lines = []
    csv_lines.append('page_number,occasion,petitions\n')
    
    for page in pages:
        if not page.strip():
            continue
        
        # Extract page number
        page_match = re.search(r'Page (\d+)', page)
        page_num = page_match.group(1) if page_match else ''
        
        # Skip pages that are just TOC, preface, or empty
        if 'Preface' in page or 'CONTENTS' in page or 'v Of the Nature' in page:
            continue
        
        # Extract the occasion title - it's typically the first all-caps text after "Page X"
        # The title is usually right after the page number and before "THE INVITATION"
        # Look for patterns like "THE FIRST SUNDAY OF ADVENT", "CHRISTMAS DAY", etc.
        
        # Try to extract title between page number and "THE INVITATION" or "Celebrant"
        title_match = re.search(r'Page \d+\s+([A-Z][A-Z\s]+?)(?:\s+(?:THE|TEE|TELE) INVITATION|Celebrant\.|$)', page)
        if title_match:
            occasion = title_match.group(1).strip()
        else:
            # Fallback: look for the first substantial all-caps sequence before any INVITATION marker
            lines = page.split('\n')
            for line in lines:
                if 'Page' in line:
                    # Extract everything after "Page X" on the first line
                    parts = line.split('Page', 1)
                    if len(parts) > 1:
                        after_page = parts[1].strip()
                        # Remove the page number
                        after_page = re.sub(r'^\d+\s+', '', after_page)
                        # Stop at any INVITATION or Celebrant marker
                        for marker in ['THE INVITATION', 'TEE INVITATION', 'TELE INVITATION', 'Celebrant.']:
                            if marker in after_page:
                                after_page = after_page.split(marker)[0].strip()
                        if len(after_page) > 5:
                            occasion = after_page
                            break
            else:
                # Last resort: use first all-caps sequence
                match = re.search(r'([A-Z]{2,}(?:\s+[A-Z]{2,})+)', page)
                if match:
                    occasion = match.group(1)
                else:
                    continue
        
        # Clean up the occasion title
        occasion = re.sub(r'\s+', ' ', occasion).strip()
        
        # Skip if occasion is too short or looks like noise
        if len(occasion) < 5:
            continue
        
        # Extract petitions - split by "Lord, hear us." to get individual petitions
        petitions = []
        petition_items = re.split(r'Lord, hear us\.', page)
        for item in petition_items:
            item = item.strip()
            # Clean up
            item = re.sub(r'P\.', '', item)
            item = re.sub(r'\s+', ' ', item)
            # Only keep substantial items that look like petitions
            if item and len(item) > 15 and not item.startswith('Page') and not re.match(r'^\d+$', item):
                # Filter out common non-petition text
                if not any(skip in item.upper() for skip in ['THE INVITATION', 'CELEBRANT', 'PEOPLE', 'READER']):
                    petitions.append(item)
        
        # Only add if we have substantial content
        if petitions:
            petitions_text = ' | '.join(petitions)
            csv_lines.append(f'"{page_num}","{occasion}","{petitions_text}"\n')
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.writelines(csv_lines)
    
    print(f"Parsed {len(csv_lines)-1} entries to {output_path}")

if __name__ == '__main__':
    parse_prayer_file(input_path, output_path)
