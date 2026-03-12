import sqlite3

conn = sqlite3.connect('assets/rsvce.db')
rows = conn.execute(
    "SELECT v.verse_id, v.text FROM verses v JOIN books b ON b._id = v.book_id "
    "WHERE b.shortname = 'Ps' AND v.chapter_id = 145 AND v.verse_id BETWEEN 8 AND 18 "
    "ORDER BY v.verse_id"
).fetchall()

for r in rows:
    print(f"Verse {r[0]}: {r[1]}")

print()
print("=== Splitting verse 13 by punctuation ===")
v13 = [r[1] for r in rows if r[0] == 13][0]
print(f"Full verse 13: {v13}")

import re
# Split by semicolons, periods, exclamation, question marks
parts = re.split(r'(?<=[;.!?])\s*', v13)
parts = [p.strip() for p in parts if p.strip()]
for i, p in enumerate(parts):
    letter = chr(ord('a') + i)
    print(f"  Part {letter}: {p}")

print()
print("=== Also check Ps 147:12-13 ===")
rows2 = conn.execute(
    "SELECT v.verse_id, v.text FROM verses v JOIN books b ON b._id = v.book_id "
    "WHERE b.shortname = 'Ps' AND v.chapter_id = 147 AND v.verse_id BETWEEN 12 AND 20 "
    "ORDER BY v.verse_id"
).fetchall()
for r in rows2:
    print(f"Verse {r[0]}: {r[1]}")

conn.close()
