from __future__ import annotations

from collections.abc import Callable, Iterator
from urllib.parse import quote
from urllib.request import urlopen
from urllib.error import URLError
import json
import re
import time

from .models import PsalmSourceRow, ReuseStatus, SourceRecord
from .normalize import parse_responsorial_section


FIRESTORE_URL = (
    "https://firestore.googleapis.com/v1/projects/catholic-missal/"
    "databases/(default)/documents/NigeriaReading?pageSize=100"
)


def iter_firestore_documents(
    fetch_page: Callable[[str | None], dict],
) -> Iterator[dict]:
    token: str | None = None
    while True:
        page = fetch_page(token)
        yield from page.get("documents", [])
        token = page.get("nextPageToken")
        if not token:
            return


def fetch_live_page(token: str | None) -> dict:
    url = FIRESTORE_URL
    if token is not None:
        url += "&pageToken=" + quote(token)
    last_error: URLError | None = None
    for attempt in range(3):
        try:
            with urlopen(url, timeout=60) as response:
                return json.load(response)
        except URLError as error:
            last_error = error
            if attempt < 2:
                time.sleep(0.5 * (attempt + 1))
    assert last_error is not None
    raise last_error


def _field(document: dict, name: str) -> str:
    return str(
        document.get("fields", {})
        .get(name, {})
        .get("stringValue", "")
    )


_RESPONSORIAL_HEADING = (
    r"RES(?:P)?ON\s*SOR\s*I?\s*AL\s+"
    r"(?:PS(?:ALM|LAM)|CANTICLE)"
)


_REFERENCE_CORRECTIONS = {
    "2025-12-13": "Ps 80:2ac, 3b, 15-16a, 18-19",
    "2025-12-16": "Ps 34:2-3, 6-7, 17-18, 19, 23",
    "2025-12-28": "Ps 128:1-2, 3, 4-5",
    "2025-12-31": "Ps 96:1-2, 11-12, 13",
    "2026-01-11": "Ps 29:1a, 2, 3ac-4, 3b, 9c-10",
    "2026-01-18": "Ps 40:2, 4ab, 7-8a, 8b-9, 10",
    "2026-01-24": "Ps 80:2-3, 5-7",
    "2026-02-09": "Ps 132:6-7, 8-10",
    "2026-03-10": "Ps 25:4-5ab, 6, 7cd, 8-9",
    "2026-03-17": "Ps 96:1-2a, 2b-3, 7-8a, 9-10ac",
    "2026-03-31": "Ps 71:1-2, 3-4a, 5-6ab, 15ab, 17",
    "2026-04-14": "Ps 93:1abc, 1d-2, 5",
    "2026-04-17": "Ps 27:1, 4, 13-14",
    "2026-05-12": "Ps 138:1ac-2a, 2bcd-3, 7c-8",
    "2026-05-25": "Ps 87:1-2, 3, 5, 6-7",
    "2026-06-23": "Ps 48:2-3ab, 3cd-4, 10-11",
    "2026-06-29": "Ps 34:2-3, 4-5, 6-7, 8-9",
    "2026-07-11": "Ps 93:1abc, 1d-2, 5",
    "2026-07-15": "Ps 94:5-6, 7-8, 9-10, 14-15",
    "2026-08-02": "Ps 145:8-9, 15-16",
    "2026-09-13": "Ps 103:1-2, 3-4, 9-10, 11-12",
    "2026-09-04": "Ps 37:3-4, 5-6, 27-28, 39-40",
    "2026-09-25": "Ps 144:1a, 2abc, 3-4",
    "2026-10-22": "Ps 33:1-2, 4-5, 11-12, 18-19",
    "2026-10-28": "Ps 19:2-3, 4-5",
    "2026-10-30": "Ps 111:1b-2, 3-4, 5-6",
    "2026-11-03": "Ps 22:26b-27, 28, 29-31, 31-32",
    "2026-11-05": "Ps 105:2-3, 4-5, 6-7",
    "2026-11-13": "Ps 119:1, 2, 10, 11, 17, 18",
    "2026-11-14": "Ps 112:1b-2, 3-4, 5-6",
    "2026-11-21": "Ps 144:1, 2, 9-10",
}


def canonicalize_nigeria_reference(date_rule: str, normalized: str) -> str:
    corrected = _REFERENCE_CORRECTIONS.get(date_rule)
    if corrected is not None:
        return corrected

    value = normalized.replace("�", "-").replace("–", "-").replace("—", "-")
    value = re.sub(
        r"\((?:r[.:]?|psalm|rev(?:elation)?).*?$",
        "",
        value,
        flags=re.IGNORECASE,
    ).rstrip(" )")
    value = re.sub(r"(?<=[.\-])[il](?=\d)", "1", value, flags=re.IGNORECASE)
    match = re.match(r"^([a-z]+|1[a-z]+)(\d+):(.*)$", value)
    if match is None:
        return value
    books = {
        "ps": "Ps",
        "deuteronomy": "Dt",
        "isaiah": "Isa",
        "exodus": "Exod",
        "daniel": "Dan",
        "jeremiah": "Jer",
        "1samuel": "1 Sam",
        "1chronicles": "1 Chr",
        "luke": "Luke",
    }
    book = books.get(match.group(1), match.group(1).title())
    groups = [
        group.strip()
        for group in re.split(r"[,.](?=\d)", match.group(3))
        if group.strip()
    ]
    return f"{book} {match.group(2)}:{', '.join(groups)}"


def _psalm_sections(body: str) -> list[str]:
    matches = re.finditer(
        rf"^\s*{_RESPONSORIAL_HEADING}\s*[-:–—]?[ \t]*(.*?)"
        r"(?=\n\s*(?:(?:OR\s+THE\s+FOLLOWING)\s*:\s*)?"
        rf"(?:{_RESPONSORIAL_HEADING}|SECOND\s+READING|ALLELUIA|"
        r"GOSPEL\s+ACCLAMATION|VERSE\s+BEFORE\s+THE\s+GOSPEL|GOSPEL|PRIEST:)"
        r"(?=\s|$)|\Z)",
        body,
        flags=re.IGNORECASE | re.DOTALL | re.MULTILINE,
    )
    return [match.group(1).strip() for match in matches if match.group(1).strip()]


def _psalm_section(body: str) -> str | None:
    sections = _psalm_sections(body)
    return sections[0] if sections else None


def _default_source() -> SourceRecord:
    return SourceRecord(
        source_id="nigeria_365_firestore",
        source_name="Catholic Missal for Nigeria",
        source_edition="live Nigerian daily corpus",
        source_territory="NG",
        source_url=FIRESTORE_URL.split("?", maxsplit=1)[0],
        source_license="No redistribution grant found in publisher terms",
        reuse_status=ReuseStatus.COMPARISON_ONLY,
        coverage="2025-2026 daily records at audit time",
        access_method="public Firestore REST",
        notes="Comparator for Nigerian Ordo assignments and displayed wording",
    )


def _iso_date(raw_date: str) -> str:
    day, month, year = raw_date.split("-")
    return f"{year}-{month}-{day}"


def extract_rows(
    page: dict,
    source: SourceRecord | None = None,
    *,
    retrieved_at: str = "2026-08-16",
) -> list[PsalmSourceRow]:
    source = source or _default_source()
    rows: list[PsalmSourceRow] = []
    for document in page.get("documents", []):
        sections = _psalm_sections(_field(document, "body"))
        raw_date = _field(document, "mandroiddates")
        if not sections or not raw_date:
            continue
        iso_date = _iso_date(raw_date)
        title_lines = [
            line.strip()
            for line in _field(document, "title").splitlines()
            if line.strip()
        ]
        celebration_title = title_lines[1] if len(title_lines) > 1 else ""
        for choice_index, section in enumerate(sections, start=1):
            parsed = parse_responsorial_section(section)
            book_match = re.match(r"^([^\d]+)", parsed.reference_normalized)
            biblical_book = book_match.group(1) if book_match else ""
            rows.append(
                PsalmSourceRow(
                usage_id=(
                    f"ng:{iso_date}:responsorial-psalm:{choice_index}"
                ),
                celebration_id="",
                celebration_title=celebration_title,
                date_rule=iso_date,
                season="",
                week="",
                weekday="",
                sunday_cycle="",
                weekday_cycle="",
                lectionary_number="",
                territory="NG",
                reading_set_kind="resolved-day",
                reading_set_priority=choice_index,
                biblical_book=biblical_book,
                psalm_number_hebrew="",
                psalm_number_vulgate="",
                reference_raw=parsed.reference_raw,
                reference_normalized=parsed.reference_normalized,
                stanza_selection_normalized=parsed.reference_normalized,
                response_verse_normalized="",
                source_id=source.source_id,
                source_name=source.source_name,
                source_edition=source.source_edition,
                source_territory=source.source_territory,
                source_url=source.source_url,
                retrieved_at=retrieved_at,
                source_license=source.source_license,
                reuse_status=source.reuse_status.value,
                response_raw=parsed.response,
                response_normalized=parsed.response_normalized,
                stanzas_raw="\n\n".join(parsed.stanzas),
                stanzas_normalized=parsed.stanzas_normalized,
                raw_sha256=parsed.raw_sha256,
                normalized_sha256=parsed.normalized_sha256,
                token_count=len(
                    (
                        parsed.response_normalized
                        + " "
                        + parsed.stanzas_normalized
                    ).split()
                ),
                comparison_target="nigeria_365_firestore",
                )
            )
    return rows


def fetch_live_rows(*, retrieved_at: str) -> list[PsalmSourceRow]:
    documents = list(iter_firestore_documents(fetch_live_page))
    return extract_rows(
        {"documents": documents},
        retrieved_at=retrieved_at,
    )
