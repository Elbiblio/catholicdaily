#!/usr/bin/env python3
"""Evaluate conservative lectionary opening matching formulas.

This is an audit tool. It emits measurements and excerpts under verification/
so we can decide which openings are safe to use without bundling full readings.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sqlite3
from pathlib import Path
from typing import Any, Iterable


BOOK_ALIASES = {
    "acts": "Acts of the Apostles",
    "amos": "Amos",
    "bar": "Baruch",
    "baruch": "Baruch",
    "col": "Colossians",
    "colossians": "Colossians",
    "cor": "Corinthians",
    "dan": "Daniel",
    "daniel": "Daniel",
    "deut": "Deuteronomy",
    "deuteronomy": "Deuteronomy",
    "eph": "Ephesians",
    "ephesians": "Ephesians",
    "est": "Esther",
    "esth": "Esther",
    "ezek": "Ezekiel",
    "ezekiel": "Ezekiel",
    "gal": "Galatians",
    "galatians": "Galatians",
    "gen": "Genesis",
    "genesis": "Genesis",
    "exod": "Exodus",
    "exodus": "Exodus",
    "hab": "Habakkuk",
    "habakkuk": "Habakkuk",
    "hag": "Haggai",
    "hagg": "Haggai",
    "haggai": "Haggai",
    "heb": "Hebrews",
    "hebrews": "Hebrews",
    "hos": "Hosea",
    "hosea": "Hosea",
    "isa": "Isaiah",
    "is": "Isaiah",
    "isaiah": "Isaiah",
    "jas": "James",
    "james": "James",
    "jer": "Jeremiah",
    "jeremiah": "Jeremiah",
    "job": "Job",
    "joel": "Joel",
    "jon": "Jonah",
    "jonah": "Jonah",
    "matt": "Matthew",
    "mt": "Matthew",
    "matthew": "Matthew",
    "mark": "Mark",
    "mk": "Mark",
    "mic": "Micah",
    "mi": "Micah",
    "micah": "Micah",
    "nah": "Nahum",
    "nahum": "Nahum",
    "num": "Numbers",
    "numbers": "Numbers",
    "luke": "Luke",
    "lk": "Luke",
    "john": "John",
    "jn": "John",
    "phil": "Philippians",
    "philippians": "Philippians",
    "prov": "Proverbs",
    "proverbs": "Proverbs",
    "rom": "Romans",
    "romans": "Romans",
    "ps": "Psalms",
    "psalm": "Psalms",
    "psalms": "Psalms",
    "rev": "Revelation",
    "revelation": "Revelation",
    "sir": "Sirach",
    "sirach": "Sirach",
    "titus": "Titus",
    "ti": "Titus",
    "tob": "Tobit",
    "tobit": "Tobit",
    "wis": "Wisdom",
    "wisdom": "Wisdom",
    "zech": "Zechariah",
    "zechariah": "Zechariah",
    "zep": "Zephaniah",
    "zeph": "Zephaniah",
    "zephaniah": "Zephaniah",
}

for ordinal in ("1", "2", "3"):
    roman = {"1": "I", "2": "II", "3": "III"}[ordinal]
    BOOK_ALIASES[f"{ordinal} sam"] = f"{roman} Samuel"
    BOOK_ALIASES[f"{ordinal} kgs"] = f"{roman} Kings"
    BOOK_ALIASES[f"{ordinal} kings"] = f"{roman} Kings"
    BOOK_ALIASES[f"{ordinal} chr"] = f"{roman} Chronicles"
    BOOK_ALIASES[f"{ordinal} chronicles"] = f"{roman} Chronicles"
    BOOK_ALIASES[f"{ordinal} cor"] = f"{roman} Corinthians"
    BOOK_ALIASES[f"{ordinal} corinthians"] = f"{roman} Corinthians"
    BOOK_ALIASES[f"{ordinal} thess"] = f"{roman} Thessalonians"
    BOOK_ALIASES[f"{ordinal} thessalonians"] = f"{roman} Thessalonians"
    BOOK_ALIASES[f"{ordinal} tim"] = f"{roman} Timothy"
    BOOK_ALIASES[f"{ordinal} timothy"] = f"{roman} Timothy"
    BOOK_ALIASES[f"{ordinal} pet"] = f"{roman} Peter"
    BOOK_ALIASES[f"{ordinal} peter"] = f"{roman} Peter"
    BOOK_ALIASES[f"{ordinal} john"] = f"{roman} John"
    BOOK_ALIASES[f"{ordinal} macc"] = f"{ordinal} Maccabees"
    BOOK_ALIASES[f"{ordinal} maccabees"] = f"{ordinal} Maccabees"

STOP_WORD_OPENINGS = {
    "",
    ")",
    ".",
    ",",
}


def evaluate_pair(
    *,
    source_opening: str,
    rendered_text: str,
    source_limit: int = 220,
    rendered_window: int = 250,
    catalog_min_chars: int = 25,
    surgical_min_chars: int = 50,
    min_source_chars_for_surgery: int = 50,
) -> dict[str, Any]:
    source_prefix = source_opening[:source_limit]
    rendered_prefix = rendered_text[:rendered_window]
    source_norm = normalize_text(source_prefix)
    rendered_norm = normalize_text(rendered_prefix)

    if len(source_norm) < catalog_min_chars:
        return _result(
            "reject_too_short",
            source_norm,
            rendered_norm,
            anchor=None,
        )

    anchor = find_best_anchor(
        source_prefix,
        rendered_prefix,
        minimum_characters=surgical_min_chars,
    )
    if len(source_norm) < min_source_chars_for_surgery:
        return _result(
            "catalog_only_short_opening",
            source_norm,
            rendered_norm,
            anchor=anchor,
        )
    if anchor is None:
        full_anchor = find_best_anchor(
            source_prefix,
            rendered_text,
            minimum_characters=surgical_min_chars,
        )
        return _result(
            "no_surgical_anchor" if full_anchor is None else "anchor_not_early",
            source_norm,
            rendered_norm,
            anchor=full_anchor,
        )
    if anchor["ambiguous"]:
        return _result("ambiguous_anchor", source_norm, rendered_norm, anchor=anchor)
    if anchor["sourceStartChar"] == 0:
        return _result("catalog_only_no_source_prefix", source_norm, rendered_norm, anchor=anchor)
    return _result("surgical_replace", source_norm, rendered_norm, anchor=anchor)


def _result(
    decision: str,
    source_norm: str,
    rendered_norm: str,
    *,
    anchor: dict[str, Any] | None,
) -> dict[str, Any]:
    return {
        "decision": decision,
        "sourceNormalizedLength": len(source_norm),
        "renderedNormalizedLength": len(rendered_norm),
        "anchorCharacters": anchor["characters"] if anchor else 0,
        "anchorTokens": anchor["tokens"] if anchor else 0,
        "ambiguous": bool(anchor and anchor["ambiguous"]),
        "sourceContainedInRendered": source_norm in rendered_norm if source_norm else False,
        "renderedContainedInSource": rendered_norm in source_norm if rendered_norm else False,
    }


def find_best_anchor(
    source: str,
    rendered: str,
    *,
    minimum_characters: int,
) -> dict[str, Any] | None:
    source_tokens = tokenize(source)
    rendered_tokens = tokenize(rendered)
    best: dict[str, Any] | None = None

    for source_index in range(len(source_tokens)):
        for rendered_index in range(len(rendered_tokens)):
            length = 0
            while (
                source_index + length < len(source_tokens)
                and rendered_index + length < len(rendered_tokens)
                and source_tokens[source_index + length]["normalized"]
                == rendered_tokens[rendered_index + length]["normalized"]
            ):
                length += 1
            if length == 0:
                continue
            characters = normalized_character_count(
                source_tokens,
                source_index,
                length,
            )
            if characters < minimum_characters:
                continue
            candidate = {
                "sourceStart": source_index,
                "renderedStart": rendered_index,
                "sourceStartChar": source_tokens[source_index]["start"],
                "renderedStartChar": rendered_tokens[rendered_index]["start"],
                "tokens": length,
                "characters": characters,
                "ambiguous": False,
            }
            if best is None or length > best["tokens"]:
                best = candidate
            elif best is not None and length == best["tokens"]:
                best["ambiguous"] = True

    return best


def normalized_character_count(tokens: list[dict[str, Any]], start: int, length: int) -> int:
    return sum(len(tokens[index]["normalized"]) for index in range(start, start + length)) + max(length - 1, 0)


def tokenize(text: str) -> list[dict[str, Any]]:
    tokens = []
    for match in re.finditer(r"[A-Za-z0-9]+(?:'[A-Za-z0-9]+)?", text):
        tokens.append(
            {
                "normalized": match.group(0).lower(),
                "start": match.start(),
                "end": match.end(),
            }
        )
    return tokens


def normalize_text(text: str) -> str:
    return " ".join(token["normalized"] for token in tokenize(text))


def fetch_db_text(db_path: Path, reference: str, max_chars: int = 700) -> str:
    parsed = parse_reference(reference)
    if parsed is None:
        return ""
    book_name, chapter, start_verse, end_verse = parsed

    conn = sqlite3.connect(db_path)
    try:
        book_row = find_book(conn, book_name)
        if book_row is None:
            return ""
        book_id = book_row[0]
        rows = conn.execute(
            """
            select verse_id, text
            from verses
            where book_id = ? and chapter_id = ? and verse_id between ? and ?
            order by verse_id
            """,
            (book_id, chapter, start_verse, end_verse),
        ).fetchall()
    finally:
        conn.close()

    return " ".join(str(text).strip() for _, text in rows if str(text).strip())[:max_chars]


def parse_reference(reference: str) -> tuple[str, int, int, int] | None:
    cleaned = reference.replace(".", ":").replace(";", ",")
    match = re.match(
        r"^\s*((?:[1-3]\s+)?[A-Za-z]+(?:\s+[A-Za-z]+)?)\s+(\d+):(\d+)[a-d]?(?:\s*-\s*(?:(\d+):)?(\d+)[a-d]?)?",
        cleaned,
    )
    if not match:
        return None
    book_raw = " ".join(match.group(1).split())
    book = BOOK_ALIASES.get(book_raw.lower(), book_raw)
    chapter = int(match.group(2))
    start = int(match.group(3))
    end_chapter = int(match.group(4)) if match.group(4) else chapter
    end = int(match.group(5)) if match.group(5) else start
    if end_chapter != chapter:
        end = start
    return book, chapter, start, end


def find_book(conn: sqlite3.Connection, book_name: str) -> tuple[int, str, str] | None:
    rows = conn.execute("select _id, text, shortname from books").fetchall()
    target = normalize_book_key(book_name)
    for row in rows:
        if normalize_book_key(str(row[1])) == target or normalize_book_key(str(row[2])) == target:
            return row
    return None


def normalize_book_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def evaluate_catalog(
    *,
    openings_csv: Path,
    db_path: Path,
    output_csv: Path,
) -> list[dict[str, Any]]:
    with openings_csv.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    results = []
    for row in rows:
        rendered = fetch_db_text(db_path, row.get("reference", ""))
        if not rendered:
            decision = "db_text_unavailable"
            metrics = {
                "decision": decision,
                "sourceNormalizedLength": len(normalize_text(row.get("opening200", ""))),
                "renderedNormalizedLength": 0,
                "anchorCharacters": 0,
                "anchorTokens": 0,
                "ambiguous": False,
                "sourceContainedInRendered": False,
                "renderedContainedInSource": False,
            }
        else:
            metrics = evaluate_pair(
                source_opening=row.get("opening200", ""),
                rendered_text=rendered,
            )
        results.append(
            {
                **{key: row.get(key, "") for key in ("id", "sourceType", "sourceFile", "season", "week", "day", "dayNum", "slot", "reference", "openingLength")},
                "renderedAvailable": bool(rendered),
                **metrics,
            }
        )

    output_csv.parent.mkdir(parents=True, exist_ok=True)
    if results:
        with output_csv.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(results[0].keys()))
            writer.writeheader()
            writer.writerows(results)
    return results


def summarize(results: list[dict[str, Any]]) -> dict[str, Any]:
    counts: dict[str, int] = {}
    for row in results:
        counts[row["decision"]] = counts.get(row["decision"], 0) + 1
    return {
        "rows": len(results),
        "decisions": counts,
        "surgicalReplaceRows": counts.get("surgical_replace", 0),
        "surgicalReplaceRate": counts.get("surgical_replace", 0) / len(results) if results else 0,
        "renderedAvailableRows": sum(1 for row in results if row["renderedAvailable"]),
    }


def create_test_bible_db(db_path: Path) -> None:
    conn = sqlite3.connect(db_path)
    try:
        conn.executescript(
            """
            create table books (_id integer primary key, text varchar(50), shortname varchar(8));
            create table verses (_id integer primary key, book_id integer, chapter_id integer, verse_id integer, text varchar(255));
            insert into books (_id, text, shortname) values (1, 'Isaiah', 'Isa');
            insert into verses (_id, book_id, chapter_id, verse_id, text) values
              (1, 1, 2, 1, 'The word which Isaiah the son of Amoz saw concerning Judah and Jerusalem.'),
              (2, 1, 2, 2, 'It shall come to pass in the latter days that all the nations shall flow to it.');
            """
        )
        conn.commit()
    finally:
        conn.close()


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--openings-csv", type=Path, required=True)
    parser.add_argument("--db", type=Path, default=Path("assets/rsvce.db"))
    parser.add_argument("--output-csv", type=Path, required=True)
    parser.add_argument("--summary-json", type=Path)
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    results = evaluate_catalog(
        openings_csv=args.openings_csv,
        db_path=args.db,
        output_csv=args.output_csv,
    )
    summary = summarize(results)
    if args.summary_json:
        args.summary_json.parent.mkdir(parents=True, exist_ok=True)
        args.summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
