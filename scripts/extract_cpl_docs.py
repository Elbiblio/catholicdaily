#!/usr/bin/env python3
"""Extract text from CPL Spanish Word documents using Word COM interface"""

import win32com.client
from pathlib import Path

script_dir = Path(r'c:\dev\catholicdaily-flutter\scripts')
doc_files = [
    'cpl_prayer_faithful_2026-04-12.doc',
    'cpl_prayer_faithful_2026-04-19.doc',
    'cpl_prayer_faithful_2026-04-26.doc'
]

word = win32com.client.Dispatch("Word.Application")
word.Visible = False

for doc_file in doc_files:
    doc_path = script_dir / doc_file
    output_path = script_dir / doc_file.replace('.doc', '.txt')
    
    try:
        doc = word.Documents.Open(str(doc_path))
        text = doc.Content.Text
        doc.Close()
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(text)
        
        print(f"Extracted: {doc_file} -> {output_path.name}")
    except Exception as e:
        print(f"Error processing {doc_file}: {e}")

word.Quit()
print("\nExtraction complete!")
