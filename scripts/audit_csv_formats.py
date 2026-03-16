#!/usr/bin/env python3
"""Audit CSV format inconsistencies in standard_lectionary_complete.csv"""
import csv
from collections import Counter, defaultdict

def main():
    with open('standard_lectionary_complete.csv', 'r', encoding='utf-8') as f:
        rows = list(csv.reader(f))

    header = rows[0]
    data = rows[1:]
    psalm_col = 8  # psalmReference column

    # 1. Count notation styles
    period_only = []
    colon_only = []
    mixed = []
    no_psalm = 0

    for r in data:
        if len(r) <= psalm_col or not r[psalm_col].strip():
            no_psalm += 1
            continue
        ps = r[psalm_col]
        before_paren = ps.split('(')[0]
        has_period = '.' in before_paren
        has_colon = ':' in before_paren
        if has_period and not has_colon:
            period_only.append(r)
        elif has_colon and not has_period:
            colon_only.append(r)
        elif has_colon and has_period:
            mixed.append(r)
        else:
            colon_only.append(r)  # neither, treat as colon

    print(f"Total data rows: {len(data)}")
    print(f"Rows with psalm: {len(data) - no_psalm}")
    print(f"Period notation (Psalm 72.1-2): {len(period_only)}")
    print(f"Colon notation (Psalm 122:1-2): {len(colon_only)}")
    print(f"Mixed (both . and :): {len(mixed)}")
    print()

    # 2. Count duplicate keys (multiple psalm options per day)
    key_psalms = defaultdict(list)
    for r in data:
        if len(r) <= psalm_col or not r[psalm_col].strip():
            continue
        key = (r[0], r[1], r[2], r[3], r[4])
        key_psalms[key].append(r[psalm_col])

    multi = {k: v for k, v in key_psalms.items() if len(v) > 1}
    print(f"Day-keys with multiple psalm rows: {len(multi)}")
    for k, v in sorted(multi.items())[:10]:
        print(f"  {k} -> {len(v)} psalms")
    print(f"  ... and {max(0, len(multi)-10)} more")
    print()

    # 3. Test what _normalizeReferenceStyle would do
    # Simulate the Dart logic
    def normalize(value):
        result = value.strip()
        if not result:
            return result
        # Book name replacements
        for old, new in [
            ('2 Samuel', '2 Sam'), ('1 Samuel', '1 Sam'),
            ('Isaiah', 'Isa'), ('Jeremiah', 'Jer'),
            ('Zephaniah', 'Zeph'), ('Malachi', 'Mal'),
            ('Genesis', 'Gen'), ('Exodus', 'Exod'),
            ('Matthew', 'Matt'), ('Romans', 'Rom'),
            ('Baruch', 'Bar'), ('Psalm', 'Ps'),
        ]:
            result = result.replace(old, new)

        # First period after digits -> colon (replaceFirstMapped)
        import re
        m = re.search(r' (\d+)\.', result)
        if m:
            result = result[:m.start()] + f' {m.group(1)}:' + result[m.end():]

        # Strip 'or' alternatives
        result = re.sub(r'\s+or\s+.+$', '', result, flags=re.IGNORECASE)
        # Strip refrain markers
        result = re.sub(r'\s*\(R\.[^)]+\)$', '', result, flags=re.IGNORECASE)
        return result

    # Show examples of normalization
    print("=== Normalization examples ===")
    samples = [
        "Psalm 72.1-2, 3-4, 7-8, 17 (R.7)",
        "Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)",
        "Psalm 1. 1-2, 3, 4-6 (R.40.5a)",
        "Psalm 51.1-2, 3-4a, 16-17 (R.17b)",
        "Ps 89:2-3, 4-5, 27+29 (R.2a)",
        "Psalm 104:1-2a.5-6.10 and 12.13-14.24 and 35c (R. cf. 30)",
    ]
    for s in samples:
        print(f"  IN:  {s}")
        print(f"  OUT: {normalize(s)}")
        print()

    # 4. Check for problematic patterns
    print("=== Potential issues ===")
    issues = []
    for r in data:
        if len(r) <= psalm_col or not r[psalm_col].strip():
            continue
        ps = r[psalm_col]
        norm = normalize(ps)

        # Issue: "Ps 1. 1-2" -> "Ps 1: 1-2" (space after colon)
        if ': ' in norm and not norm.startswith('Ps '):
            issues.append(('space_after_colon', r[0], r[1], r[2], ps, norm))

        # Issue: "Psalm 1. 1-2" where chapter is single digit and has space
        import re
        if re.search(r'Ps \d+: \d', norm):
            issues.append(('space_after_colon_in_ref', r[0], r[1], r[2], ps, norm))

        # Issue: still has period notation after normalization
        before_paren = norm.split('(')[0]
        if '.' in before_paren and ':' in before_paren:
            pass  # mixed is fine (verse separators)

    print(f"Found {len(issues)} potential issues")
    for cat, *rest in issues[:15]:
        print(f"  [{cat}] {rest[0]},{rest[1]},{rest[2]}: {rest[3]} -> {rest[4]}")

    # 5. Check movable feasts in memorial_feasts.csv
    print()
    print("=== Memorial feasts with date_rule (movable) ===")
    with open('memorial_feasts.csv', 'r', encoding='utf-8') as f:
        mrows = list(csv.reader(f))
    for r in mrows[1:]:
        if len(r) < 8:
            continue
        month, day, rule = r[4], r[5], r[6]
        if rule.strip() and not month.strip():
            print(f"  {r[0]}: rule='{rule}', month={month}, day={day}, first_reading={r[8] if len(r)>8 else ''}")

if __name__ == '__main__':
    main()
