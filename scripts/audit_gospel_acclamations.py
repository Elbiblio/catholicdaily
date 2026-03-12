import re
import sqlite3
from collections import defaultdict
from pathlib import Path

DB_PATH = Path(r"c:\dev\catholicdaily-flutter\assets\readings.db")

PREFIX_RE = re.compile(r'^(see\s+|cf\.?\s+)', re.IGNORECASE)
LEADING_REF_RE = re.compile(
    r'^(?P<ref>(?:See\s+|Cf\.?\s+)?(?:[1-3]\s+)?[A-Za-z][A-Za-z\s.]*?\s+\d+:\d+[a-z]?(?:\s*(?:,|-)\s*\d+[a-z]?)*(?:\s*,\s*\d+[a-z]?)*(?:\s+and\s+\d+[a-z]?)?)',
    re.IGNORECASE,
)


def extract_leading_ref(value: str) -> str | None:
    value = value.strip()
    match = LEADING_REF_RE.match(value)
    if not match:
        return None
    return re.sub(r'\s+', ' ', match.group('ref')).strip()


def base_ref(value: str) -> str:
    value = PREFIX_RE.sub('', value).strip()
    value = re.sub(r'([0-9]+)[a-z]+', r'\1', value, flags=re.IGNORECASE)
    value = re.sub(r'\s+', ' ', value)
    return value.lower()


def main() -> None:
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute(
        "SELECT DISTINCT gospel_acclamation FROM readings WHERE gospel_acclamation IS NOT NULL AND TRIM(gospel_acclamation) != '' ORDER BY gospel_acclamation"
    ).fetchall()
    conn.close()

    grouped = defaultdict(list)
    for (raw_value,) in rows:
        leading = extract_leading_ref(raw_value)
        if not leading:
            continue
        grouped[base_ref(leading)].append((leading, raw_value))

    suspicious = []
    for key, values in grouped.items():
        unique_refs = sorted({leading for leading, _ in values})
        if len(unique_refs) < 2:
            continue
        has_suffix = any(re.search(r'\d+[a-z]+', ref, re.IGNORECASE) for ref in unique_refs)
        has_plain = any(not re.search(r'\d+[a-z]+', ref, re.IGNORECASE) for ref in unique_refs)
        if has_suffix and has_plain:
            suspicious.append((key, unique_refs, sorted({raw for _, raw in values})))

    for key, refs, raws in suspicious:
        print(f'BASE: {key}')
        print('  refs:')
        for ref in refs:
            print(f'    - {ref}')
        print('  stored:')
        for raw in raws:
            print(f'    - {raw}')
        print()

    print(f'SUSPICIOUS_GROUPS={len(suspicious)}')


if __name__ == '__main__':
    main()
