#!/usr/bin/env python3
"""Analyze Prayer of the Faithful extraction - show what's on each page"""

import re
from pathlib import Path

input_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967_extracted.txt')

with open(input_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Split by page markers
pages = re.split(r'={80}\nFILE: EPUB/page_\d+\.html\n={80}\n', content)

print(f'Total pages: {len(pages)}')
print()

# Analyze each page
for i, page in enumerate(pages):
    if not page.strip():
        continue
    
    # Extract page number
    page_match = re.search(r'Page (\d+)', page)
    page_num = page_match.group(1) if page_match else '?'
    
    # Get first 150 chars to see what the page is about
    preview = page.strip()[:150].replace('\n', ' ')
    
    print(f'Page {page_num}: {preview}...')
