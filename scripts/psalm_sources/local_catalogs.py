from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import re

from .models import PsalmSourceRow, SourceRecord
from .normalize import normalize_reference, normalize_words


_CATALOGS = (
    ("standard_lectionary_complete.csv", "local_standard_lectionary"),
    ("lectionary_psalms.csv", "local_sunday_psalms"),
    ("lectionary_psalms_weekday.csv", "local_weekday_psalms"),
)


def _first(raw: dict[str, str | None], *keys: str) -> str:
    for key in keys:
        value = raw.get(key)
        if value is not None and value.strip():
            return value.strip()
    return ""


def validate_local_row(raw: dict[str, str | None]) -> list[str]:
    responses = [
        _first(raw, "Refrain Text"),
        _first(raw, "Refrain Text RSVCE"),
        _first(raw, "Refrain Text NABRE"),
        _first(raw, "psalm_response"),
    ]
    errors: list[str] = []
    for response in responses:
        lowered = response.lower()
        if lowered.startswith(
            (
                "alleluia",
                "come, wisdom",
                "come, leader",
                "come, king",
                "come, root",
                "come, key",
                "come, radiant dawn",
                "come, emmanuel",
            )
        ):
            errors.append("response_contains_acclamation")
        if response and re.match(
            r"^(?:John|Luke|Matthew|Mark|Isaiah)\s+\d",
            response,
            re.IGNORECASE,
        ):
            errors.append("response_contains_scripture_reference")
    return sorted(set(errors))


def _load_registry(root: Path) -> dict[str, SourceRecord]:
    raw = json.loads(
        (root / "scripts/psalm_sources/source_registry.json").read_text(
            encoding="utf-8"
        )
    )
    return {
        item.source_id: item
        for item in (SourceRecord.from_dict(record) for record in raw)
    }


def _sha(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _book_and_number(reference: str) -> tuple[str, str]:
    match = re.match(r"\s*(Psalm|Ps|[1-3]?\s*[A-Za-z]+)\s*(\d+)?", reference)
    if not match:
        return "", ""
    book = match.group(1).strip()
    number = match.group(2) or ""
    if book.lower() in {"ps", "psalm"}:
        book = "Ps"
    return book, number


def _row_from_catalog(
    raw: dict[str, str | None],
    *,
    line_number: int,
    source: SourceRecord,
    retrieved_at: str,
) -> PsalmSourceRow | None:
    reference = _first(raw, "psalm_reference", "Full Reference")
    if not reference:
        return None
    response = _first(raw, "psalm_response", "Refrain Text")
    normalized_response = normalize_words(response)
    normalized_reference = normalize_reference(reference)
    book, psalm_number = _book_and_number(reference)
    errors = validate_local_row(raw)
    return PsalmSourceRow(
        usage_id=f"{source.source_id}:row:{line_number}",
        celebration_id="",
        celebration_title=_first(raw, "source_title"),
        date_rule=_first(raw, "Day", "day"),
        season=_first(raw, "Season", "season"),
        week=_first(raw, "Week", "week"),
        weekday=_first(raw, "Day", "day"),
        sunday_cycle=_first(raw, "Sunday Cycle", "sunday_cycle"),
        weekday_cycle=_first(raw, "Weekday Cycle", "weekday_cycle"),
        lectionary_number=_first(
            raw,
            "Lectionary Number",
            "lectionary_number",
        ),
        territory=source.source_territory,
        reading_set_kind="catalog",
        reading_set_priority=1,
        biblical_book=book,
        psalm_number_hebrew=psalm_number,
        psalm_number_vulgate="",
        reference_raw=reference,
        reference_normalized=normalized_reference,
        stanza_selection_normalized=normalized_reference,
        response_verse_normalized="",
        source_id=source.source_id,
        source_name=source.source_name,
        source_edition=source.source_edition,
        source_territory=source.source_territory,
        source_url=source.source_url,
        retrieved_at=retrieved_at,
        source_license=source.source_license,
        reuse_status=source.reuse_status.value,
        response_raw=response,
        response_normalized=normalized_response,
        stanzas_raw="",
        stanzas_normalized="",
        raw_sha256=_sha(response),
        normalized_sha256=_sha(normalized_response),
        token_count=len(normalized_response.split()),
        notes=";".join(errors),
        display_eligible=False,
    )


def load_local_psalm_rows(
    root: Path,
    *,
    retrieved_at: str = "2026-08-16",
) -> list[PsalmSourceRow]:
    registry = _load_registry(root)
    rows: list[PsalmSourceRow] = []
    for relative_path, source_id in _CATALOGS:
        source = registry[source_id]
        with (root / relative_path).open(
            encoding="utf-8-sig",
            newline="",
        ) as handle:
            for line_number, raw in enumerate(csv.DictReader(handle), start=2):
                row = _row_from_catalog(
                    raw,
                    line_number=line_number,
                    source=source,
                    retrieved_at=retrieved_at,
                )
                if row is not None:
                    rows.append(row)
    return rows
