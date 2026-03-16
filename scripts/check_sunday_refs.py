import json

data = json.load(open('scripts/sunday_references_extracted.json'))

# Check missing/incomplete gospels
missing_g = [d for d in data if not d['gospel'] or ':' not in d['gospel']]
print(f"{len(missing_g)} entries with missing/incomplete gospel")
for d in missing_g[:20]:
    print(f"  {d['season']} {d['week']} {d['cycle']}: gospel='{d['gospel']}'")

# Check missing second readings
missing_s = [d for d in data if not d['second_reading']]
print(f"\n{len(missing_s)} entries with missing second reading")
for d in missing_s[:20]:
    print(f"  {d['season']} {d['week']} {d['cycle']}: special='{d['special']}'")

# Check gospels missing book prefix
no_book = [d for d in data if d['gospel'] and ':' in d['gospel'] and not any(d['gospel'].startswith(b) for b in ['Mt','Mk','Lk','Jn','John','Luke','Mark','Matt'])]
print(f"\n{len(no_book)} gospels missing book prefix")
for d in no_book[:20]:
    print(f"  {d['season']} {d['week']} {d['cycle']}: gospel='{d['gospel']}'")

# Total coverage
print(f"\nTotal entries: {len(data)}")
for season in ['Advent','Lent','Easter','Ordinary Time','Christmas']:
    count = sum(1 for d in data if d['season'] == season)
    print(f"  {season}: {count}")
