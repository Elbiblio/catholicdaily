from __future__ import annotations

from contextlib import closing
from dataclasses import dataclass
from pathlib import Path
import re
import sqlite3

from .models import PsalmEditionText


_BOOK_ALIASES = {
    "ps": "ps",
    "psalm": "ps",
    "psalms": "ps",
    "isa": "isa",
    "isaiah": "isa",
    "jer": "jer",
    "jeremiah": "jer",
    "dan": "dan",
    "daniel": "dan",
    "deut": "deut",
    "dt": "deut",
    "deuteronomy": "deut",
    "1 sam": "1sam",
    "1 samuel": "1sam",
    "1 chronicles": "1chr",
    "1 chr": "1chr",
    "ex": "ex",
    "exodus": "ex",
    "luke": "luke",
    "lk": "luke",
}


@dataclass(frozen=True)
class SelectionGroup:
    chapter: int
    verses: tuple[int, ...]
    normalized: str


@dataclass(frozen=True)
class ParsedSelection:
    book: str
    chapter: int
    groups: tuple[SelectionGroup, ...]
    normalized: str


def _canonical_book(value: str) -> str:
    compact = re.sub(r"\s+", " ", value.strip().lower().replace(".", ""))
    return _BOOK_ALIASES.get(compact, compact.replace(" ", ""))


def _verse_number(value: str) -> int:
    match = re.match(r"\d+", value.strip())
    if not match:
        raise ValueError(f"Invalid verse selector: {value!r}")
    return int(match.group(0))


def _expand_group(value: str) -> tuple[int, ...]:
    verses: list[int] = []
    for component in value.split("+"):
        component = component.strip()
        if "-" in component:
            start_raw, end_raw = component.split("-", 1)
            start = _verse_number(start_raw)
            end = _verse_number(end_raw)
            verses.extend(range(start, end + 1))
        else:
            verses.append(_verse_number(component))
    return tuple(dict.fromkeys(verses))


def parse_selection(reference: str) -> ParsedSelection:
    clean = reference.replace("–", "-").replace("—", "-").strip()
    clean = re.sub(r"\s*\([^)]*(?:R\.?|℟)[^)]*\).*?$", "", clean, flags=re.I)
    clean = clean.rstrip("+ ")
    match = re.match(r"^(.+?)\s+(\d+)\s*[:.]\s*(.+)$", clean)
    if not match:
        raise ValueError(f"Unsupported psalm or canticle reference: {reference!r}")

    book = _canonical_book(match.group(1))
    chapter = int(match.group(2))
    raw_groups = [
        group.strip()
        for group in re.split(r"\s*(?:,|\.(?=\s*\d))\s*", match.group(3))
        if group.strip()
    ]
    groups = tuple(
        SelectionGroup(
            chapter=chapter,
            verses=_expand_group(group),
            normalized=re.sub(r"\s+", "", group.lower()),
        )
        for group in raw_groups
    )
    normalized = f"{book}{chapter}:{','.join(group.normalized for group in groups)}"
    return ParsedSelection(
        book=book,
        chapter=chapter,
        groups=groups,
        normalized=normalized,
    )


def selection_id_for(reference_normalized: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", reference_normalized.lower()).strip("_")


def resolve_book_id(connection: sqlite3.Connection, book: str) -> int:
    rows = connection.execute("SELECT _id, text, shortname FROM books").fetchall()
    for book_id, title, shortname in rows:
        candidates = {_canonical_book(str(title)), _canonical_book(str(shortname))}
        if book in candidates:
            return int(book_id)
    raise LookupError(f"Book {book!r} is not present in Bible database")


def lookup_verse(
    connection: sqlite3.Connection,
    book_id: int,
    chapter: int,
    verse: int,
) -> str:
    row = connection.execute(
        """SELECT text FROM verses
           WHERE book_id = ? AND chapter_id = ? AND verse_id = ?
           ORDER BY _id LIMIT 1""",
        (book_id, chapter, verse),
    ).fetchone()
    if row is None or not str(row[0]).strip():
        raise LookupError(f"Missing verse book={book_id} {chapter}:{verse}")
    return str(row[0]).strip()


def extract_bible_selection(
    database: Path,
    *,
    edition_id: str,
    reference: str,
    response_text: str = "",
    source_url: str = "",
) -> PsalmEditionText:
    parsed = parse_selection(reference)
    with closing(sqlite3.connect(database)) as connection:
        book_id = resolve_book_id(connection, parsed.book)
        stanzas = tuple(
            " ".join(
                lookup_verse(connection, book_id, group.chapter, verse)
                for verse in group.verses
            )
            for group in parsed.groups
        )
    return PsalmEditionText(
        selection_id=selection_id_for(parsed.normalized),
        edition_id=edition_id,
        reference_normalized=parsed.normalized,
        response_text=response_text,
        stanzas=stanzas,
        source_url=source_url or f"repo://{database.as_posix()}",
    )
