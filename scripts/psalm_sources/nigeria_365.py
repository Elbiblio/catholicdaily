from __future__ import annotations

from collections.abc import Callable, Iterator
from urllib.parse import quote
from urllib.request import urlopen
import json
import re

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
    with urlopen(url, timeout=60) as response:
        return json.load(response)


def _field(document: dict, name: str) -> str:
    return str(
        document.get("fields", {})
        .get(name, {})
        .get("stringValue", "")
    )


def _psalm_section(body: str) -> str | None:
    match = re.search(
        r"RESPONSORIAL\s+PSALM\s*:?[ \t]*(.*?)"
        r"(?=\n\s*(?:SECOND\s+READING|ALLELUIA|GOSPEL\s+ACCLAMATION|GOSPEL)\b)",
        body,
        flags=re.IGNORECASE | re.DOTALL,
    )
    return match.group(1).strip() if match else None


def _default_source() -> SourceRecord:
    return SourceRecord(
        source_id="nigeria_365_firestore",
        source_name="Catholic Missal for Nigeria / 365 Readings",
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
        section = _psalm_section(_field(document, "body"))
        raw_date = _field(document, "mandroiddates")
        if not section or not raw_date:
            continue
        parsed = parse_responsorial_section(section)
        iso_date = _iso_date(raw_date)
        title_lines = [
            line.strip()
            for line in _field(document, "title").splitlines()
            if line.strip()
        ]
        celebration_title = title_lines[1] if len(title_lines) > 1 else ""
        rows.append(
            PsalmSourceRow(
                usage_id=f"ng:{iso_date}:responsorial-psalm:1",
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
                reading_set_priority=1,
                biblical_book="Ps",
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
