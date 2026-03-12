import sqlite3
import re

conn = sqlite3.connect('assets/rsvce.db')

print("=== Psalm 145:13 detailed split analysis ===")
v13 = conn.execute(
    "SELECT v.text FROM verses v JOIN books b ON b._id = v.book_id "
    "WHERE b.shortname = 'Ps' AND v.chapter_id = 145 AND v.verse_id = 13"
).fetchone()[0]
print(f"Full: {v13}")
print()

# The verse is: "Thy kingdom is an everlasting kingdom,and thy dominion endures throughout all generations. The LORD is faithful in all his words, and gracious in all his deeds."
# Expected lectionary parts for 13cd:
# c = "The LORD is faithful in all his words"
# d = "and gracious in all his deeds"
#
# So we need to split into at LEAST 4 parts:
# a = "Thy kingdom is an everlasting kingdom"
# b = "and thy dominion endures throughout all generations"
# c = "The LORD is faithful in all his words"
# d = "and gracious in all his deeds"

# Strategy: split on major punctuation first (.;!?), then split each result on commas
# But only split on commas that separate independent clauses (before conjunctions or new subjects)

# Step 1: Split on sentence-ending punctuation
sentences = re.split(r'(?<=[.!?;])\s*', v13.strip())
sentences = [s.strip() for s in sentences if s.strip()]
print(f"After sentence split ({len(sentences)} parts):")
for i, s in enumerate(sentences):
    print(f"  {i}: {s}")

print()

# Step 2: For each sentence, split on comma+conjunction patterns
def split_clause(text):
    """Split a clause on comma boundaries that separate independent sub-clauses."""
    # Remove trailing punctuation for splitting
    stripped = re.sub(r'[.!?;:]\s*$', '', text).strip()
    
    # Split on ", and" patterns that separate parallel clauses in Hebrew poetry
    # Also split on ",and" (no space - as in our data)
    parts = re.split(r',\s*(?=and\b|but\b|or\b|yet\b|for\b|nor\b)', stripped)
    return [p.strip() for p in parts if p.strip()]

all_parts = []
for sentence in sentences:
    sub = split_clause(sentence)
    all_parts.extend(sub)

print(f"After clause split ({len(all_parts)} parts):")
for i, p in enumerate(all_parts):
    letter = chr(ord('a') + i)
    print(f"  {letter}: {p}")

print()
print("13cd should give parts c and d:")
if len(all_parts) >= 4:
    print(f"  c: {all_parts[2]}")
    print(f"  d: {all_parts[3]}")
else:
    print(f"  PROBLEM: only {len(all_parts)} parts found")

print()
print("=== Psalm 145:8 (refrain verse) ===")
v8 = conn.execute(
    "SELECT v.text FROM verses v JOIN books b ON b._id = v.book_id "
    "WHERE b.shortname = 'Ps' AND v.chapter_id = 145 AND v.verse_id = 8"
).fetchone()[0]
print(f"Full: {v8}")

conn.close()
