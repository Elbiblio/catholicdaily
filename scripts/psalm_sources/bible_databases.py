from __future__ import annotations

from contextlib import closing
from dataclasses import dataclass
from pathlib import Path
import re
import sqlite3
from typing import Iterable

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
    "dn": "dan",
    "daniel": "dan",
    "deut": "deut",
    "dt": "deut",
    "deuteronomy": "deut",
    "1 sam": "1sam",
    "1 samuel": "1sam",
    "first samuel": "1sam",
    "firstsamuel": "1sam",
    "1 chronicles": "1chr",
    "1 chr": "1chr",
    "first chronicles": "1chr",
    "firstchronicles": "1chr",
    "tob": "tob",
    "tobit": "tob",
    "jdt": "judith",
    "jud": "judith",
    "judith": "judith",
    "ex": "ex",
    "exod": "ex",
    "exodus": "ex",
    "luke": "luke",
    "lk": "luke",
}


_KNOWN_REFERENCE_CORRECTIONS = {
    "ps 23: 13a, 3b4, 5, 6": "Ps 23:1-3a, 3b-4, 5, 6",
    "psalm 138.12a, 1-2a, 2bc-3, 7c-8": "Ps 138:1-2a, 2bc-3, 7c-8",
    "ps 138.12a, 1-2a, 2bc-3, 7c-8": "Ps 138:1-2a, 2bc-3, 7c-8",
    "psalm 122.1-2, 3-4, 7-8, 9-10": (
        "Ps 122:1-2, 3-4, 4-5, 6-7, 8-9"
    ),
    "ps 122.1-2, 3-4, 7-8, 9-10": "Ps 122:1-2, 3-4, 4-5, 6-7, 8-9",
    "ps 114:1-2, 3-4, 5-6, 8-9": "Ps 116:1-2, 3-4, 5-6, 8-9",
    "psalm 27.1, 2, 3, 13-15": "Ps 27:1, 2, 3, 13-14",
    "ps 27.1, 2, 3, 13-15": "Ps 27:1, 2, 3, 13-14",
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
    clean = re.sub(r"\s*\((?:R\.?|℟)[^)]*\).*?$", "", clean, flags=re.I)
    clean = clean.lstrip(" (")
    clean = re.sub(r"\s+and\s+", ", ", clean, flags=re.I)
    clean = clean.rstrip("+ ")
    correction_key = re.sub(r"^psalm\s+", "ps ", clean.lower())
    clean = _KNOWN_REFERENCE_CORRECTIONS.get(
        clean.lower(),
        _KNOWN_REFERENCE_CORRECTIONS.get(correction_key, clean),
    )
    if re.match(r"^\d+\s*[:.]", clean):
        clean = f"Ps {clean}"
    match = re.match(r"^(.+?)\s*(\d+)\s*[:.]\s*(.+)$", clean)
    if not match:
        raise ValueError(f"Unsupported psalm or canticle reference: {reference!r}")

    book = _canonical_book(match.group(1))
    chapter = int(match.group(2))
    raw_selection = re.sub(
        r";\s*(\d+)\s*\.\s*(?=\d)",
        r";\1:",
        match.group(3),
    )
    raw_groups = [
        group.strip()
        for group in re.split(r"\s*(?:,|;|\.(?=\s*\d))\s*", raw_selection)
        if group.strip()
    ]
    groups_list: list[SelectionGroup] = []
    current_chapter = chapter
    for group in raw_groups:
        chapter_marker = re.match(r"^(\d+)\s*[:.]\s*(.+)$", group)
        selector = group
        if chapter_marker:
            current_chapter = int(chapter_marker.group(1))
            selector = chapter_marker.group(2)
        groups_list.append(
            SelectionGroup(
                chapter=current_chapter,
                verses=_expand_group(selector),
                normalized=re.sub(r"\s+", "", selector.lower()),
            )
        )
    groups = tuple(groups_list)
    normalized_groups: list[str] = []
    prior_chapter = chapter
    for group in groups:
        prefix = f"{group.chapter}:" if group.chapter != prior_chapter else ""
        normalized_groups.append(prefix + group.normalized)
        prior_chapter = group.chapter
    normalized = f"{book}{chapter}:{','.join(normalized_groups)}"
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
    rows = connection.execute(
        """SELECT text FROM verses
           WHERE book_id = ? AND chapter_id = ? AND verse_id = ?
           ORDER BY _id""",
        (book_id, chapter, verse),
    ).fetchall()
    values = [str(row[0]).strip() for row in rows if str(row[0]).strip()]
    if not values:
        raise LookupError(f"Missing verse book={book_id} {chapter}:{verse}")
    return " ".join(values)


def _edition_verse_numbers(
    *,
    edition_id: str,
    book: str,
    chapter: int,
    verses: tuple[int, ...],
    psalm_offset: int = 0,
) -> tuple[int, ...]:
    """Map lectionary numbering to the bundled edition's verse keys."""

    mapped: list[int] = []
    for verse in verses:
        value = verse + psalm_offset
        if edition_id == "local_rsvce" and book == "dan" and chapter == 3:
            # The RSVCE database keys the Greek canticle at 3:35-68, while the
            # lectionary cites the continuous Daniel numbering 3:57-90.
            if verse >= 57:
                value = verse - 22
        elif edition_id == "local_rsvce" and book == "tob" and chapter == 13:
            # The imported RSVCE row for Tobit 13:3 also contains verse 4.
            if verse == 4:
                value = 3
        elif edition_id == "local_nabre" and book == "ps" and chapter == 2:
            # The bundled NABRE row 2:11 contains its final beatitude and has
            # no separately keyed 2:12 row.
            if verse == 12:
                value = 11
        mapped.append(value)
    return tuple(dict.fromkeys(mapped))


def extract_bible_selections(
    database: Path,
    *,
    edition_id: str,
    selections: Iterable[tuple[str, str]],
    source_url: str = "",
) -> list[PsalmEditionText]:
    parsed_rows = [(parse_selection(reference), response) for reference, response in selections]
    output: list[PsalmEditionText] = []
    with closing(sqlite3.connect(database)) as connection:
        book_ids: dict[str, int] = {}
        offsets: dict[int, int] = {}
        for parsed, response_text in parsed_rows:
            if parsed.book not in book_ids:
                book_ids[parsed.book] = resolve_book_id(connection, parsed.book)
            book_id = book_ids[parsed.book]
            try:
                stanzas = tuple(
                    " ".join(
                        lookup_verse(
                            connection,
                            book_id,
                            group.chapter,
                            verse,
                        )
                        for verse in _edition_verse_numbers(
                            edition_id=edition_id,
                            book=parsed.book,
                            chapter=group.chapter,
                            verses=group.verses,
                            psalm_offset=_psalm_group_offset(
                                database=database,
                                connection=connection,
                                book_id=book_id,
                                edition_id=edition_id,
                                book=parsed.book,
                                group=group,
                                offsets=offsets,
                            ),
                        )
                    )
                    for group in parsed.groups
                )
            except LookupError as error:
                raise LookupError(
                    f"{error}; selection={parsed.normalized!r}; edition={edition_id}"
                ) from error
            output.append(
                PsalmEditionText(
                    selection_id=selection_id_for(parsed.normalized),
                    edition_id=edition_id,
                    reference_normalized=parsed.normalized,
                    response_text=response_text,
                    stanzas=stanzas,
                    source_url=source_url or f"repo://{database.as_posix()}",
                )
            )
    return output


def _max_verse(
    connection: sqlite3.Connection,
    book_id: int,
    chapter: int,
) -> int:
    row = connection.execute(
        "SELECT MAX(verse_id) FROM verses WHERE book_id = ? AND chapter_id = ?",
        (book_id, chapter),
    ).fetchone()
    return int(row[0]) if row and row[0] is not None else 0


def _rsvce_psalm_offset(
    database: Path,
    connection: sqlite3.Connection,
    book_id: int,
    chapter: int,
) -> int:
    """Align title-counting lectionary verses with the RSVCE asset.

    The bundled NABRE database numbers many psalm superscriptions as verse 1,
    matching the lectionary references, while the bundled RSVCE database keeps
    those superscriptions outside the numbered text. Comparing chapter lengths
    gives a deterministic one-verse offset without rewriting either edition.
    """

    nabre_database = database.with_name("nabre.db")
    if not nabre_database.exists():
        return 0
    current_max = _max_verse(connection, book_id, chapter)
    with closing(sqlite3.connect(nabre_database)) as nabre:
        try:
            nabre_book = resolve_book_id(nabre, "ps")
        except LookupError:
            return 0
        nabre_max = _max_verse(nabre, nabre_book, chapter)
    difference = current_max - nabre_max
    return difference if difference in {-1, -2, -3} else 0


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
        offsets: dict[int, int] = {}
        stanzas = tuple(
            " ".join(
                lookup_verse(
                    connection,
                    book_id,
                    group.chapter,
                    verse,
                )
                for verse in _edition_verse_numbers(
                    edition_id=edition_id,
                    book=parsed.book,
                    chapter=group.chapter,
                    verses=group.verses,
                    psalm_offset=_psalm_group_offset(
                        database=database,
                        connection=connection,
                        book_id=book_id,
                        edition_id=edition_id,
                        book=parsed.book,
                        group=group,
                        offsets=offsets,
                    ),
                )
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


def _psalm_group_offset(
    *,
    database: Path,
    connection: sqlite3.Connection,
    book_id: int,
    edition_id: str,
    book: str,
    group: SelectionGroup,
    offsets: dict[int, int],
) -> int:
    if edition_id != "local_rsvce" or book != "ps" or 1 in group.verses:
        return 0
    if group.chapter not in offsets:
        offsets[group.chapter] = _rsvce_psalm_offset(
            database,
            connection,
            book_id,
            group.chapter,
        )
    return offsets[group.chapter]
