"""
Parse extracted weekday lectionary PDF text into structured CSV data.
Extracts: Season, Week, Day, Weekday Cycle, Psalm Reference, Psalm Response,
          Gospel Acclamation Reference, Gospel Acclamation Text
"""
import re
import csv
import os

# Map lectionary number ranges to Season/Week based on Table of Contents
# From weekday-a-1993.pdf TOC (page 3)
SECTION_MAP_A = {
    # Advent
    (2, 15): ("Advent", "1"),
    (16, 28): ("Advent", "2"),
    (29, 40): ("Advent", "3"),
    (42, 63): ("Advent", "Dec 17-24"),
    # Christmas
    (64, 76): ("Christmas", "Octave"),
    (77, 89): ("Christmas", "After New Year"),
    (91, 103): ("Christmas", "After Epiphany"),
    # Ordinary Time Year I pages
    (106, 118): ("Ordinary Time", "1"),
    (119, 131): ("Ordinary Time", "2"),
    (132, 145): ("Ordinary Time", "3"),
    (146, 160): ("Ordinary Time", "4"),
    (161, 176): ("Ordinary Time", "5"),
    (177, 190): ("Ordinary Time", "6"),
    (191, 204): ("Ordinary Time", "7"),
    (205, 218): ("Ordinary Time", "8"),
    (219, 239): ("Ordinary Time", "9"),
    # Ordinary Time Year II pages
    (240, 254): ("Ordinary Time", "1"),
    (255, 270): ("Ordinary Time", "2"),
    (271, 286): ("Ordinary Time", "3"),
    (287, 302): ("Ordinary Time", "4"),
    (303, 316): ("Ordinary Time", "5"),
    (317, 329): ("Ordinary Time", "6"),
    (330, 342): ("Ordinary Time", "7"),
    (343, 356): ("Ordinary Time", "8"),
    (357, 368): ("Ordinary Time", "9"),
    # Lent
    (374, 385): ("Lent", "Weekdays"),
    (386, 398): ("Lent", "1"),
    (399, 414): ("Lent", "2"),
    (415, 435): ("Lent", "3"),
    (436, 456): ("Lent", "4"),
    (457, 485): ("Lent", "5"),
    (486, 495): ("Holy Week", ""),
    # Easter
    (496, 512): ("Easter", "Octave"),
    (513, 525): ("Easter", "2"),
    (526, 541): ("Easter", "3"),
    (542, 556): ("Easter", "4"),
    (557, 570): ("Easter", "5"),
    (571, 583): ("Easter", "6"),
    (584, 600): ("Easter", "7"),
}


def parse_full_text(text_path):
    """Parse the full extracted text from a weekday lectionary PDF."""
    with open(text_path, 'r', encoding='utf-8') as f:
        full_text = f.read()
    
    # Split into pages
    pages = re.split(r'={80}\nPAGE \d+\n={80}', full_text)
    
    # Combine all text for line-by-line parsing
    all_lines = []
    for page in pages:
        lines = page.strip().split('\n')
        all_lines.extend(lines)
    
    return all_lines


def extract_entries(all_lines, pdf_label="A"):
    """
    Extract psalm and acclamation entries from the parsed lines.
    Returns list of dicts with structured data.
    """
    entries = []
    current_season = ""
    current_week = ""
    current_day = ""
    current_day_number = ""
    current_weekday_cycle = ""
    
    # Track what we're reading
    i = 0
    n = len(all_lines)
    
    # Patterns
    # Season headers
    season_patterns = [
        (r'THE SEASON OF ADVENT', "Advent"),
        (r'WEEKDAYS OF ADVENT', "Advent"),
        (r'FIRST WEEK OF ADVENT', "Advent"),
        (r'SECOND WEEK OF ADVENT', "Advent"),
        (r'THIRD WEEK OF ADVENT', "Advent"),
        (r'ADVENT WEEKDAYS.*DECEMBER 17', "Advent"),
        (r'CHRISTMAS SEASON', "Christmas"),
        (r'OCTAVE OF CHRISTMAS', "Christmas"),
        (r'ORDINARY TIME', "Ordinary Time"),
        (r'SEASON OF LENT', "Lent"),
        (r'WEEKDAYS OF LENT', "Lent"),
        (r'HOLY WEEK', "Holy Week"),
        (r'SEASON OF EASTER', "Easter"),
        (r'OCTAVE OF EASTER', "Easter"),
    ]
    
    week_pattern = re.compile(
        r'(FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH|NINTH)\s+WEEK\s+'
        r'(?:OF|IN)\s+(ADVENT|LENT|EASTER|ORDINARY TIME)',
        re.IGNORECASE
    )
    
    week_number_map = {
        'FIRST': '1', 'SECOND': '2', 'THIRD': '3', 'FOURTH': '4',
        'FIFTH': '5', 'SIXTH': '6', 'SEVENTH': '7', 'EIGHTH': '8', 'NINTH': '9'
    }
    
    # Day pattern: number followed by DAY NAME
    day_pattern = re.compile(r'^(\d+)\s+(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)$')
    
    # Responsorial Psalm pattern
    psalm_pattern = re.compile(
        r'RESPONSORIAL\s+PSALM\s+(Psalm\s+\d+[\w\.\-,\s\(\)]*)',
        re.IGNORECASE
    )
    
    # Psalm response pattern (R. line)
    response_pattern = re.compile(r'^R\.\s+(.+)$')
    
    # Gospel acclamation pattern
    acclamation_header = re.compile(
        r'GOSPEL\s+ACCLAMATI\s*O\s*N\s*(.*)',
        re.IGNORECASE
    )
    
    # Year/Cycle indicator in readings
    year_indicator = re.compile(r'YEAR\s+(I+|A|B|C)', re.IGNORECASE)
    
    current_entry = None
    in_acclamation = False
    acclamation_ref = ""
    acclamation_lines = []
    reading_year = ""
    
    while i < n:
        line = all_lines[i].strip()
        
        # Check for week headers
        wm = week_pattern.search(line)
        if wm:
            word = wm.group(1).upper()
            season_word = wm.group(2).upper()
            current_week = week_number_map.get(word, word)
            if 'ADVENT' in season_word:
                current_season = "Advent"
            elif 'LENT' in season_word:
                current_season = "Lent"
            elif 'EASTER' in season_word:
                current_season = "Easter"
            elif 'ORDINARY' in season_word:
                current_season = "Ordinary Time"
            i += 1
            continue
        
        # Check for special season markers
        if 'OCTAVE OF CHRISTMAS' in line.upper():
            current_season = "Christmas"
            current_week = "Octave"
        elif 'OCTAVE OF EASTER' in line.upper():
            current_season = "Easter"
            current_week = "Octave"
        elif 'HOLY WEEK' in line.upper() and 'FIFTH WEEK' not in line.upper():
            current_season = "Holy Week"
            current_week = ""
        elif re.search(r'ADVENT WEEKDAYS.*DECEMBER 17', line, re.IGNORECASE):
            current_season = "Advent"
            current_week = "Dec 17-24"
        elif re.search(r'WEEKDAYS BETWEEN NEW YEAR', line, re.IGNORECASE):
            current_season = "Christmas"
            current_week = "After New Year"
        elif re.search(r'WEEKDAYS BETWEEN EPIPHANY', line, re.IGNORECASE):
            current_season = "Christmas"
            current_week = "After Epiphany"
        
        # Check for day headers
        dm = day_pattern.match(line)
        if dm:
            current_day_number = dm.group(1)
            current_day = dm.group(2).title()
            reading_year = ""  # Reset
            i += 1
            continue
        
        # Track Year indicators in reading headers
        if 'FIRST READING' in line.upper():
            ym = year_indicator.search(line)
            if ym:
                reading_year = ym.group(1).upper()
        
        # Check for Responsorial Psalm
        pm = psalm_pattern.search(line)
        if pm:
            psalm_ref_raw = pm.group(1).strip()
            # Clean up the reference - get full reference including (R.x)
            # Sometimes continues on same line or next
            full_psalm_line = line
            psalm_ref = re.sub(r'RESPONSORIAL\s+PSALM\s+', '', full_psalm_line, flags=re.IGNORECASE).strip()
            
            # Get response text (next line starting with R.)
            response_text = ""
            j = i + 1
            while j < min(i + 5, n):
                rline = all_lines[j].strip()
                rm = response_pattern.match(rline)
                if rm:
                    response_text = rm.group(1).strip()
                    # Check if response continues on next line (no verse number)
                    k = j + 1
                    while k < min(j + 3, n):
                        next_line = all_lines[k].strip()
                        if next_line and not re.match(r'^\d+\s', next_line) and not next_line.startswith('R.') and not next_line.startswith('or:'):
                            # Could be continuation of response
                            if len(next_line) < 80 and not re.match(r'^(He|She|They|The|It|You|We|In|For|A|O|I|My|Our|Let|Give|May|Save|Come|Blessed|Seek|Behold)', next_line):
                                response_text += " " + next_line
                            break
                        break
                    break
                j += 1
            
            # Determine weekday cycle
            if reading_year in ('I', 'II'):
                weekday_cycle = reading_year
            elif reading_year == 'A':
                weekday_cycle = "I"
            elif reading_year == 'B':
                weekday_cycle = "II"
            else:
                # Default based on which PDF
                weekday_cycle = "I" if pdf_label == "A" else "II"
            
            current_entry = {
                'season': current_season,
                'week': current_week,
                'day': current_day,
                'lectionary_number': current_day_number,
                'weekday_cycle': weekday_cycle,
                'sunday_cycle': '',  # Weekdays don't have Sunday cycle
                'psalm_reference': psalm_ref,
                'response_text': response_text,
                'acclamation_ref': '',
                'acclamation_text': '',
            }
            i = j + 1 if j > i else i + 1
            continue
        
        # Check for Gospel Acclamation
        am = acclamation_header.search(line)
        if am and current_entry:
            acclamation_ref = am.group(1).strip()
            # Clean common patterns
            acclamation_ref = re.sub(r'^See\s+', 'See ', acclamation_ref)
            
            # Skip boilerplate lines and get the actual verse text
            acclamation_text_parts = []
            j = i + 1
            while j < min(i + 8, n):
                aline = all_lines[j].strip()
                # Skip boilerplate
                if 'This verse may accompany' in aline or \
                   'If the Alleluia is not sung' in aline or \
                   'the acclamation is omitted' in aline or \
                   aline == '':
                    j += 1
                    continue
                # Stop at Gospel reading header or next section
                if re.match(r'GO\s*S\s*P\s*E\s*L\s', aline) or \
                   re.match(r'FIRST READING', aline) or \
                   re.match(r'\d+\s+(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)', aline) or \
                   re.match(r'RESPONSORIAL', aline):
                    break
                acclamation_text_parts.append(aline)
                j += 1
            
            acclamation_text = ' '.join(acclamation_text_parts).strip()
            
            current_entry['acclamation_ref'] = acclamation_ref
            current_entry['acclamation_text'] = acclamation_text
            
            # Save entry
            entries.append(current_entry.copy())
            current_entry = None
            i = j
            continue
        
        i += 1
    
    # Don't forget last entry if no acclamation followed
    if current_entry:
        entries.append(current_entry.copy())
    
    return entries


def determine_cycle_from_context(entries, pdf_label):
    """
    Post-process to fix weekday cycle assignments.
    Year I = odd years, Year II = even years.
    The PDF 'A' contains Year I readings for OT, 
    PDF 'B' contains Year II readings for OT.
    But seasons like Advent/Lent/Easter have same readings both years.
    """
    for entry in entries:
        season = entry['season']
        if season in ('Advent', 'Christmas', 'Lent', 'Holy Week', 'Easter'):
            # These seasons have the same readings regardless of year I/II
            entry['weekday_cycle'] = 'I/II'
    return entries


def write_csv(entries, output_path):
    """Write entries to CSV."""
    fieldnames = [
        'Season', 'Week', 'Day', 'Weekday Cycle', 'Sunday Cycle',
        'Full Reference', 'Refrain Text', 'Acclamation Ref', 'Acclamation Text',
        'Lectionary Number'
    ]
    
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        
        for entry in entries:
            writer.writerow({
                'Season': entry['season'],
                'Week': entry['week'],
                'Day': entry['day'],
                'Weekday Cycle': entry['weekday_cycle'],
                'Sunday Cycle': entry['sunday_cycle'],
                'Full Reference': entry['psalm_reference'],
                'Refrain Text': entry['response_text'],
                'Acclamation Ref': entry['acclamation_ref'],
                'Acclamation Text': entry['acclamation_text'],
                'Lectionary Number': entry.get('lectionary_number', ''),
            })
    
    print(f"Wrote {len(entries)} entries to {output_path}")


def main():
    base_dir = r'c:\dev\catholicdaily-flutter\scripts'
    
    # Parse PDF A (Year I for OT)
    print("=== Parsing Weekday A (Year I) ===")
    lines_a = parse_full_text(os.path.join(base_dir, 'weekday_a_full.txt'))
    entries_a = extract_entries(lines_a, pdf_label="A")
    entries_a = determine_cycle_from_context(entries_a, "A")
    print(f"  Found {len(entries_a)} entries")
    
    # Parse PDF B (Year II for OT)
    print("=== Parsing Weekday B (Year II) ===")
    lines_b = parse_full_text(os.path.join(base_dir, 'weekday_b_full.txt'))
    entries_b = extract_entries(lines_b, pdf_label="B")
    entries_b = determine_cycle_from_context(entries_b, "B")
    print(f"  Found {len(entries_b)} entries")
    
    # Write individual CSVs for inspection
    write_csv(entries_a, os.path.join(base_dir, 'weekday_a_psalms.csv'))
    write_csv(entries_b, os.path.join(base_dir, 'weekday_b_psalms.csv'))
    
    # Combine: For seasons with same readings (Advent/Lent/Easter), 
    # keep only one copy. For OT, keep both Year I and Year II.
    combined = []
    seen_seasonal = set()
    
    for entry in entries_a:
        if entry['weekday_cycle'] == 'I/II':
            key = (entry['season'], entry['week'], entry['day'])
            if key not in seen_seasonal:
                seen_seasonal.add(key)
                combined.append(entry)
        else:
            combined.append(entry)
    
    for entry in entries_b:
        if entry['weekday_cycle'] == 'I/II':
            key = (entry['season'], entry['week'], entry['day'])
            if key not in seen_seasonal:
                seen_seasonal.add(key)
                combined.append(entry)
        else:
            combined.append(entry)
    
    # Sort
    season_order = {
        'Advent': 0, 'Christmas': 1, 'Ordinary Time': 2, 
        'Lent': 3, 'Holy Week': 4, 'Easter': 5
    }
    day_order = {
        'Monday': 0, 'Tuesday': 1, 'Wednesday': 2, 
        'Thursday': 3, 'Friday': 4, 'Saturday': 5, 'Sunday': 6
    }
    
    def sort_key(e):
        s = season_order.get(e['season'], 99)
        w = e['week']
        # Try to convert week to int for sorting
        try:
            w_num = int(w)
        except (ValueError, TypeError):
            w_num = 99
        d = day_order.get(e['day'], 99)
        c = 0 if e['weekday_cycle'] in ('I', 'I/II') else 1
        return (s, w_num, d, c)
    
    combined.sort(key=sort_key)
    
    output_path = os.path.join(os.path.dirname(base_dir), 'lectionary_psalms_weekday.csv')
    write_csv(combined, output_path)
    
    # Print summary
    print(f"\n=== Summary ===")
    print(f"Year I entries: {len(entries_a)}")
    print(f"Year II entries: {len(entries_b)}")
    print(f"Combined (deduplicated seasonal): {len(combined)}")
    
    # Show first few entries as sample
    print(f"\n=== Sample entries (first 10) ===")
    for e in combined[:10]:
        print(f"  {e['season']} W{e['week']} {e['day']} Cycle:{e['weekday_cycle']} | "
              f"{e['psalm_reference'][:40]} | R. {e['response_text'][:40]}")
    
    # Show some OT entries
    ot_entries = [e for e in combined if e['season'] == 'Ordinary Time']
    print(f"\n=== Sample OT entries (first 10) ===")
    for e in ot_entries[:10]:
        print(f"  OT W{e['week']} {e['day']} Cycle:{e['weekday_cycle']} | "
              f"{e['psalm_reference'][:40]} | R. {e['response_text'][:40]}")


if __name__ == '__main__':
    main()
