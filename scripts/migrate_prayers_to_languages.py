#!/usr/bin/env python3
"""
Migration script to split existing prayer HTML files into language-specific folders.
This script reads prayer files from assets/prayers/ and splits them into:
- assets/prayers/en/filename.html (English content)
- assets/prayers/la/filename.html (Latin content)
- Creates placeholder files for other languages (es, pt, fr, tl, it, pl, vi, ko)
"""

import os
import re
from pathlib import Path

# Configuration
PRAYERS_DIR = Path("assets/prayers")
LANGUAGES = ["en", "la", "es", "pt", "fr", "tl", "it", "pr", "vi", "ko"]
LATIN_MARKERS = ["In Latin", "In Latin:"]

def clean_html_line(line):
    """Remove HTML tags but preserve text content."""
    cleaned = line
    cleaned = re.sub(r'<[^>]*>', '', cleaned)
    cleaned = cleaned.replace('&nbsp;', ' ')
    cleaned = cleaned.replace('&amp;', '&')
    cleaned = cleaned.replace('&lt;', '<')
    cleaned = cleaned.replace('&gt;', '>')
    cleaned = cleaned.replace('&#146;', "'")
    cleaned = cleaned.replace('&#225;', 'á')
    cleaned = cleaned.replace('&#233;', 'é')
    cleaned = cleaned.replace('&#237;', 'í')
    cleaned = cleaned.replace('&#243;', 'ó')
    cleaned = cleaned.replace('&#250;', 'ú')
    cleaned = cleaned.replace('&#193;', 'Á')
    cleaned = cleaned.replace('&#201;', 'É')
    cleaned = cleaned.replace('&#205;', 'Í')
    cleaned = cleaned.replace('&#211;', 'Ó')
    cleaned = cleaned.replace('&#218;', 'Ú')
    return cleaned.strip()

def parse_prayer_html(content):
    """Parse prayer HTML and split into English and Latin sections."""
    english_lines = []
    latin_lines = []
    is_latin_section = False
    
    lines = content.split('\n')
    
    for line in lines:
        trimmed = line.strip()
        
        # Check for Latin markers
        is_marker = any(marker in trimmed for marker in LATIN_MARKERS)
        if is_marker:
            is_latin_section = True
            continue
        
        # Clean the line
        clean_line = clean_html_line(line)
        
        if is_latin_section:
            if clean_line:
                latin_lines.append(line)  # Keep original HTML formatting
        else:
            if clean_line:
                english_lines.append(line)  # Keep original HTML formatting
    
    return english_lines, latin_lines

def create_language_file(language, filename, content_lines):
    """Create a language-specific prayer file."""
    lang_dir = PRAYERS_DIR / language
    lang_dir.mkdir(parents=True, exist_ok=True)
    
    filepath = lang_dir / filename
    
    if content_lines:
        # Reconstruct HTML with proper structure
        html_content = "<HTML>\n<BODY>\n"
        html_content += "\n".join(content_lines)
        html_content += "\n</BODY>\n</HTML>\n"
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(html_content)
        print(f"Created: {filepath}")
    else:
        # Create placeholder file with comment
        placeholder = f"<HTML>\n<BODY>\n<!-- Translation for {filename} in {language} will be added here -->\n</BODY>\n</HTML>\n"
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(placeholder)
        print(f"Created placeholder: {filepath}")

def migrate_prayer_file(filepath):
    """Migrate a single prayer file to language-specific folders."""
    filename = filepath.name
    
    print(f"\nProcessing: {filename}")
    
    # Read original file
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Parse content
    english_lines, latin_lines = parse_prayer_html(content)
    
    # Create English file
    create_language_file("en", filename, english_lines)
    
    # Create Latin file
    create_language_file("la", filename, latin_lines)
    
    # Create placeholder files for other languages
    for lang in ["es", "pt", "fr", "tl", "it", "pl", "vi", "ko"]:
        create_language_file(lang, filename, [])

def main():
    """Main migration function."""
    print("Starting prayer migration...")
    print(f"Source directory: {PRAYERS_DIR.absolute()}")
    
    # Get all HTML files in prayers directory (excluding subdirectories)
    html_files = [f for f in PRAYERS_DIR.glob("*.html") if f.is_file()]
    
    print(f"Found {len(html_files)} prayer files to migrate")
    
    # Migrate each file
    for filepath in html_files:
        migrate_prayer_file(filepath)
    
    print("\nMigration complete!")
    print("Note: Placeholder files have been created for es, pt, fr, tl, it, pl, vi, ko")
    print("These will need to be filled with official translations.")

if __name__ == "__main__":
    main()
