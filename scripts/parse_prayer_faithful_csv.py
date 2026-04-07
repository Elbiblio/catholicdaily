#!/usr/bin/env python3
"""Parse extracted Prayer of the Faithful text into CSV format"""

import re
from pathlib import Path

input_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967_extracted.txt')
output_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967.csv')

def parse_prayer_file(input_path, output_path):
    """Parse the extracted text into CSV format"""
    
    with open(input_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split by page markers
    pages = re.split(r'={80}\nFILE: EPUB/page_\d+\.html\n={80}\n', content)
    
    csv_lines = []
    csv_lines.append('occasion,petitions,page_number\n')
    
    for page in pages:
        if not page.strip():
            continue
        
        # Extract page number
        page_match = re.search(r'Page (\d+)', page)
        page_num = page_match.group(1) if page_match else ''
        
        # Look for occasion title (usually all caps)
        # Common patterns: "THE FIRST SUNDAY OF ADVENT", "CHRISTMAS DAY", "APPENDIX"
        occasion_patterns = [
            r'(THE\s+(?:FIRST|SECOND|THIRD|FOURTH|FIFTH)\s+SUNDAY\s+OF\s+(?:ADVENT|LENT|EASTER))',
            r'(THE\s+NATIVITY\s+OF\s+OUR\s+LORD)',
            r'(CHRISTMAS\s+DAY)',
            r'(SUNDAY\s+WITHIN\s+THE\s+OCTAVE)',
            r'(THE\s+OCTAVE\s+OF\s+THE\s+NATIVITY)',
            r'(THE\s+MOST\s+HOLY\s+NAME\s+OF\s+JESUS)',
            r'(EPIPHANY)',
            r'(THE\s+BAPTISM\s+OF\s+THE\s+LORD)',
            r'(LENT)',
            r'(HOLY\s+WEEK)',
            r'(EASTER\s+SUNDAY)',
            r'(PENTECOST)',
            r'(TRINITY\s+SUNDAY)',
            r'(CORPUS\s+CHRISTI)',
            r'(APPENDIX)',
            r'(YOUTH\s+RALLIES)',
            r'(WEDDINGS)',
            r'(HOLY\s+ORDERS)',
            r'(MATRIMONY)',
            r'(MISSIONS)',
            r'(FUNERALS)',
            r'(CONFIRMATION)',
            r'(BAPTISM)',
        ]
        
        occasion = None
        for pattern in occasion_patterns:
            match = re.search(pattern, page, re.IGNORECASE)
            if match:
                occasion = match.group(1).upper()
                break
        
        if not occasion:
            # Try to find any all-caps word sequence that might be a title
            # Look for sequences of 2+ all-caps words
            match = re.search(r'([A-Z]{2,}(?:\s+[A-Z]{2,})+)', page)
            if match:
                candidate = match.group(1)
                # Filter out common non-occasion words
                if candidate not in ['Lord hear us', 'Lord graciously', 'Page', 'THE PETITIONS']:
                    occasion = candidate
        
        if not occasion:
            continue
        
        # Extract petitions - the page content is mostly petitions with "Lord, hear us." responses
        petitions = []
        # Split by "Lord, hear us." to get individual petitions
        petition_items = re.split(r'Lord, hear us\.', page)
        for item in petition_items:
            item = item.strip()
            # Clean up
            item = re.sub(r'P\.', '', item)
            item = re.sub(r'\s+', ' ', item)
            # Only keep substantial items that look like petitions (not page numbers or short fragments)
            if item and len(item) > 15 and not item.startswith('Page') and not re.match(r'^\d+$', item):
                petitions.append(item)
        
        # Only add if we have substantial content
        if petitions:
            petitions_text = ' | '.join(petitions)
            csv_lines.append(f'"{occasion}","{petitions_text}","{page_num}"\n')
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.writelines(csv_lines)
    
    print(f"Parsed {len(csv_lines)-1} entries to {output_path}")

if __name__ == '__main__':
    parse_prayer_file(input_path, output_path)
