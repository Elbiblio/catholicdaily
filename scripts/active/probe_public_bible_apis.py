#!/usr/bin/env python3
"""Probe public Bible APIs for Catholic regional text-family candidates."""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
from html import unescape
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen


BOOK_ALIASES = {
    "1 Samuel": ("I Samuel", "1 Sam"),
    "2 Samuel": ("II Samuel", "2 Sam"),
    "1 Kings": ("I Kings", "1 Kgs"),
    "2 Kings": ("II Kings", "2 Kgs"),
    "1 Corinthians": ("I Corinthians", "1 Cor"),
    "2 Corinthians": ("II Corinthians", "2 Cor"),
    "1 Thessalonians": ("I Thessalonians", "1 Thess"),
    "2 Thessalonians": ("II Thessalonians", "2 Thess"),
    "1 Timothy": ("I Timothy", "1 Tim"),
    "2 Timothy": ("II Timothy", "2 Tim"),
    "1 Peter": ("I Peter", "1 Pet"),
    "2 Peter": ("II Peter", "2 Pet"),
    "1 John": ("I John", "1 John"),
    "2 John": ("II John", "2 John"),
    "3 John": ("III John", "3 John"),
}


BOLLS_TRANSLATIONS_URL = "https://bolls.life/static/bolls/app/views/languages.json"
CANDIDATE_TERMS = (
    "rsv",
    "nabre",
    "nab",
    "esv",
    "catholic",
    "douay",
    "rheims",
    "jerusalem",
    "nrsv",
    "drb",
)
SAMPLES = [
    ("John", 3, 16),
    ("Matthew", 5, 3),
    ("Luke", 1, 28),
    ("Isaiah", 7, 14),
    ("Romans", 8, 28),
]


def fetch_json(url: str):
    request = Request(url, headers={"User-Agent": "catholicdaily-audit/1.0"})
    with urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def list_bolls_candidates() -> list[dict[str, str]]:
    data = fetch_json(BOLLS_TRANSLATIONS_URL)
    candidates = []
    for language in data:
        language_name = language.get("language", "")
        for translation in language.get("translations", []):
            short_name = translation.get("short_name", "")
            full_name = translation.get("full_name", "")
            haystack = f"{language_name} {short_name} {full_name}".lower()
            if any(term in haystack for term in CANDIDATE_TERMS):
                candidates.append(
                    {
                        "language": language_name,
                        "shortName": short_name,
                        "fullName": full_name,
                    }
                )
    return candidates


def bolls_verse(version: str, book: str, chapter: int, verse: int) -> str:
    url = f"https://bolls.life/get-verse/{version}/{quote(book)}/{chapter}/{verse}/"
    data = fetch_json(url)
    if not isinstance(data, dict):
        return ""
    return str(data.get("text", ""))


def local_verse(db_path: Path, book: str, chapter: int, verse: int) -> str:
    conn = sqlite3.connect(db_path)
    try:
        names = [book, *BOOK_ALIASES.get(book, ())]
        placeholders = ",".join("?" for _ in names)
        row = conn.execute(
            f"select _id from books where text in ({placeholders}) or shortname in ({placeholders})",
            (*names, *names),
        ).fetchone()
        if row is None:
            return ""
        verse_row = conn.execute(
            """
            select text from verses
            where book_id = ? and chapter_id = ? and verse_id = ?
            """,
            (row[0], chapter, verse),
        ).fetchone()
        return str(verse_row[0]) if verse_row else ""
    finally:
        conn.close()


def normalized_words(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", unescape(value or ""))
    text = text.replace("\u2018", "'").replace("\u2019", "'")
    text = text.replace("\u201c", '"').replace("\u201d", '"')
    text = re.sub(r"\[[A-Z0-9]+\]", " ", text)
    return " ".join(re.findall(r"[a-z0-9]+(?:'[a-z0-9]+)?", text.lower()))


def compare_bolls_to_local(version: str, db_path: Path) -> dict:
    rows = []
    for book, chapter, verse in SAMPLES:
        local = normalized_words(local_verse(db_path, book, chapter, verse))
        external = normalized_words(bolls_verse(version, book, chapter, verse))
        rows.append(
            {
                "reference": f"{book} {chapter}:{verse}",
                "sameWords": local == external,
                "localWords": local,
                "externalWords": external,
            }
        )
    return {
        "version": version,
        "dbPath": str(db_path),
        "sameCount": sum(1 for row in rows if row["sameWords"]),
        "sampleCount": len(rows),
        "rows": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("verification/public-bible-api-probe/bolls_probe.json"),
    )
    args = parser.parse_args()

    result = {
        "bollsCandidates": list_bolls_candidates(),
        "comparisons": [
            compare_bolls_to_local("RSV2CE", Path("assets/rsvce.db")),
            compare_bolls_to_local("NABRE", Path("assets/nabre.db")),
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "bollsCandidates"}, indent=2))
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
