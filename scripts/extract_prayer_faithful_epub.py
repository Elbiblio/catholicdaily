#!/usr/bin/env python3
"""Extract text content from Prayer of the Faithful EPUB"""

import zipfile
import re
from pathlib import Path

epub_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967.epub')
output_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967_extracted.txt')

def clean_html(html_content):
    """Remove HTML tags and extract text"""
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', '', html_content)
    # Clean up whitespace
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def extract_text_from_epub(epub_path, output_path):
    """Extract all text from EPUB pages"""
    with zipfile.ZipFile(epub_path, 'r') as z:
        # Get all page files
        page_files = sorted([f for f in z.namelist() if f.startswith('EPUB/page_') and f.endswith('.html')])
        
        with open(output_path, 'w', encoding='utf-8') as out:
            for page_file in page_files:
                try:
                    content = z.read(page_file).decode('utf-8')
                    text = clean_html(content)
                    if text:  # Only write if there's actual text content
                        out.write(f"\n\n{'='*80}\n")
                        out.write(f"FILE: {page_file}\n")
                        out.write(f"{'='*80}\n")
                        out.write(text)
                except Exception as e:
                    print(f"Error processing {page_file}: {e}")
    
    print(f"Extracted text to {output_path}")

if __name__ == '__main__':
    extract_text_from_epub(epub_path, output_path)
