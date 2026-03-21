#!/usr/bin/env python3
import re
from pathlib import Path

def main():
    script_file = Path('scripts/weekday_b_full.txt')
    
    with open(script_file, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Find all Acts 13 references
    acts_matches = re.findall(r'Acts 13\.(\d+)(?:-(\d+))?', content)
    print(f"Found Acts 13 references: {acts_matches}")
    
    # Find SECOND READING lines
    second_reading_lines = re.findall(r'SECOND READING (.+)', content)
    acts_second_readings = [line for line in second_reading_lines if 'Acts 13' in line]
    print(f"Acts 13 SECOND READING lines: {acts_second_readings}")
    
    # Test the extraction on a specific section
    sections = re.split(r'\n(?=[A-Z]+ READING|A reading from the holy gospel)', content)
    
    for i, section in enumerate(sections):
        if 'Acts 13' in section:
            print(f"\n=== Section {i} containing Acts 13 ===")
            lines = section.split('\n')[:10]  # First 10 lines
            for line in lines:
                print(f"  {line}")
            if i > 2:  # Limit output
                break

if __name__ == "__main__":
    main()
