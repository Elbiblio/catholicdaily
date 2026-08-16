from __future__ import annotations

import argparse
import csv
from dataclasses import fields, replace
import json
import os
from pathlib import Path
import re
import tempfile
from typing import Iterable

from psalm_sources.compare import compare_rows, redact_for_commit
from psalm_sources.bible_databases import (
    extract_bible_selections,
    parse_selection,
    selection_id_for,
)
from psalm_sources.edition_corpus import (
    EDITION_TEXT_FIELDS,
    USAGE_FIELDS,
    build_wide_comparison,
    edition_text_rows,
    usage_rows,
    wide_fieldnames,
    write_csv_rows,
)
from psalm_sources.local_catalogs import load_local_psalm_rows
from psalm_sources.models import (
    PsalmEditionText,
    PsalmSourceRow,
    PsalmUsage,
    SourceRecord,
)
from psalm_sources.modern_psalter import parse_liturgy_page
from psalm_sources.nigeria_365 import extract_rows, fetch_live_rows


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_HEADER = (
    "usage_id",
    "territory",
    "celebration_id",
    "date_rule",
    "sunday_cycle",
    "weekday_cycle",
    "lectionary_number",
    "reading_set_kind",
    "reference_normalized",
    "response_text",
    "stanzas_text",
    "source_id",
    "source_edition",
    "source_url",
    "display_priority",
)


def _registry() -> list[SourceRecord]:
    raw = json.loads(
        (ROOT / "scripts/psalm_sources/source_registry.json").read_text(
            encoding="utf-8"
        )
    )
    records = [SourceRecord.from_dict(item) for item in raw]
    ids = [record.source_id for record in records]
    if len(ids) != len(set(ids)):
        raise ValueError("source registry contains duplicate source IDs")
    return records


def _selection_key(reference: str) -> str:
    return re.sub(r"\(r\.[^)]*\)", "", reference, flags=re.IGNORECASE)


def _compare_to_nigeria(rows: list[PsalmSourceRow]) -> list[PsalmSourceRow]:
    targets: dict[str, PsalmSourceRow] = {}
    for row in rows:
        if row.source_id == "nigeria_365_firestore":
            targets.setdefault(_selection_key(row.reference_normalized), row)

    compared: list[PsalmSourceRow] = []
    for row in rows:
        target = targets.get(_selection_key(row.reference_normalized))
        if target is None:
            compared.append(
                replace(
                    row,
                    comparison_target="nigeria_365_firestore",
                    difference_class="missing_text",
                    review_status="unmatched",
                )
            )
            continue
        metrics = compare_rows(row, target)
        compared.append(
            replace(
                row,
                comparison_target="nigeria_365_firestore",
                reference_match_score=metrics["reference_match_score"],
                response_match_score=metrics["response_match_score"],
                stanza_match_score=metrics["stanza_match_score"],
                text_match_score=metrics["text_match_score"],
                difference_class=metrics["difference_class"],
                review_status="compared",
            )
        )
    return compared


def _atomic_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        newline="",
        delete=False,
        dir=path.parent,
    ) as handle:
        handle.write(text)
        temporary = Path(handle.name)
    os.replace(temporary, path)


def _csv_text(fieldnames: Iterable[str], rows: Iterable[dict]) -> str:
    import io

    output = io.StringIO(newline="")
    writer = csv.DictWriter(
        output,
        fieldnames=list(fieldnames),
        extrasaction="ignore",
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def _write_inventory(
    output_dir: Path,
    records: list[SourceRecord],
) -> None:
    fieldnames = (
        "source_id",
        "source_name",
        "source_edition",
        "source_territory",
        "source_url",
        "source_license",
        "reuse_status",
        "coverage",
        "access_method",
        "notes",
    )
    rows = []
    for record in sorted(records, key=lambda item: item.source_id):
        row = record.__dict__.copy()
        row["reuse_status"] = record.reuse_status.value
        rows.append(row)
    _atomic_text(
        output_dir / "psalm_source_inventory.csv",
        _csv_text(fieldnames, rows),
    )


def _write_comparison(
    output_dir: Path,
    rows: list[PsalmSourceRow],
) -> None:
    fieldnames = [field.name for field in fields(PsalmSourceRow)]
    committed = [redact_for_commit(row) for row in rows]
    committed.sort(
        key=lambda row: (
            row.usage_id,
            row.source_id,
            row.reference_normalized,
        )
    )
    _atomic_text(
        output_dir / "psalm_source_comparison.csv",
        _csv_text(fieldnames, (row.to_dict() for row in committed)),
    )


def _runtime_reference(reference: str) -> str:
    return _selection_key(reference).rstrip(",")


def _runtime_rows(rows: list[PsalmSourceRow]) -> list[dict[str, str | int]]:
    eligible = [
        row
        for row in rows
        if row.display_eligible and row.stanzas_raw.strip()
    ]
    eligible.sort(
        key=lambda row: (
            row.display_priority,
            row.territory,
            row.usage_id,
        )
    )
    return [
        {
            "usage_id": row.usage_id,
            "territory": row.territory,
            "celebration_id": row.celebration_id,
            "date_rule": row.date_rule,
            "sunday_cycle": row.sunday_cycle,
            "weekday_cycle": row.weekday_cycle,
            "lectionary_number": row.lectionary_number,
            "reading_set_kind": row.reading_set_kind,
            "reference_normalized": _runtime_reference(
                row.reference_normalized
            ),
            "response_text": row.response_raw,
            "stanzas_text": row.stanzas_raw.replace("\n", r"\n"),
            "source_id": row.source_id,
            "source_edition": row.source_edition,
            "source_url": row.source_url,
            "display_priority": row.display_priority,
        }
        for row in eligible
    ]


def _write_runtime(output_dir: Path, rows: list[PsalmSourceRow]) -> int:
    runtime = _runtime_rows(rows)
    _atomic_text(
        output_dir / "responsorial_psalm_texts.csv",
        _csv_text(RUNTIME_HEADER, runtime),
    )
    return len(runtime)


def _write_report(
    output_dir: Path,
    *,
    records: list[SourceRecord],
    rows: list[PsalmSourceRow],
    runtime_count: int,
    modern_metadata: dict[str, str],
    retrieved_at: str,
) -> None:
    nigeria = [
        row for row in rows if row.source_id == "nigeria_365_firestore"
    ]
    malformed = [row for row in rows if row.notes]
    conflicts = [
        row
        for row in rows
        if row.difference_class
        not in {"", "exact", "punctuation_only", "missing_text"}
    ]
    unmatched = [row for row in rows if row.review_status == "unmatched"]
    report = {
        "retrieved_at": retrieved_at,
        "source_count": len(records),
        "row_count": len(rows),
        "nigeria_usage_count": len(nigeria),
        "nigeria_raw_unique_count": len(
            {row.raw_sha256 for row in nigeria}
        ),
        "nigeria_normalized_unique_count": len(
            {row.normalized_sha256 for row in nigeria}
        ),
        "nigeria_selection_unique_count": len(
            {_selection_key(row.reference_normalized) for row in nigeria}
        ),
        "display_eligible_count": runtime_count,
        "malformed_row_count": len(malformed),
        "conflict_count": len(conflicts),
        "unmatched_count": len(unmatched),
        "difference_classes": sorted(
            {row.difference_class for row in rows if row.difference_class}
        ),
        "modern_psalter_fixture": modern_metadata,
    }
    _atomic_text(
        output_dir / "responsorial_psalm_audit_report.json",
        json.dumps(report, indent=2, sort_keys=True) + "\n",
    )


def _full_text_corpus(
    rows: list[PsalmSourceRow],
    *,
    douay_db: Path | None = None,
) -> tuple[list[PsalmUsage], list[PsalmEditionText]]:
    usages: list[PsalmUsage] = []
    reference_by_selection: dict[str, tuple[str, str]] = {}
    seen_usages: set[tuple[str, str, str]] = set()

    for row in rows:
        parsed = parse_selection(row.reference_raw)
        selection_id = selection_id_for(parsed.normalized)
        usage_key = (row.usage_id, selection_id, row.source_id)
        if usage_key not in seen_usages:
            usages.append(
                PsalmUsage(
                    usage_id=row.usage_id,
                    selection_id=selection_id,
                    territory=row.territory or "WORLD",
                    date_rule=row.date_rule,
                    celebration_id=row.celebration_id,
                    celebration_title=row.celebration_title,
                    reading_set_kind=row.reading_set_kind,
                    reading_set_priority=row.reading_set_priority,
                    sunday_cycle=row.sunday_cycle,
                    weekday_cycle=row.weekday_cycle,
                    lectionary_number=row.lectionary_number,
                    response_text=row.response_raw,
                )
            )
            seen_usages.add(usage_key)
        reference_by_selection.setdefault(
            selection_id,
            (row.reference_raw, row.response_raw),
        )

    selections = [
        reference_by_selection[selection_id]
        for selection_id in sorted(reference_by_selection)
    ]
    edition_rows = extract_bible_selections(
        ROOT / "assets/rsvce.db",
        edition_id="local_rsvce",
        selections=selections,
        source_url="repo://assets/rsvce.db",
    )
    edition_rows.extend(
        extract_bible_selections(
            ROOT / "assets/nabre.db",
            edition_id="local_nabre",
            selections=selections,
            source_url="repo://assets/nabre.db",
        )
    )
    if douay_db is not None:
        edition_rows.extend(
            extract_bible_selections(
                douay_db,
                edition_id="douay_rheims",
                selections=selections,
                source_url=str(douay_db),
            )
        )

    for row in rows:
        if row.source_id != "nigeria_365_firestore" or not row.stanzas_raw.strip():
            continue
        parsed = parse_selection(row.reference_raw)
        edition_rows.append(
            PsalmEditionText(
                selection_id=selection_id_for(parsed.normalized),
                edition_id="nigeria_365_firestore",
                reference_normalized=parsed.normalized,
                response_text=row.response_raw,
                stanzas=tuple(
                    value.strip()
                    for value in re.split(r"\n\s*\n", row.stanzas_raw)
                    if value.strip()
                ),
                source_url=row.source_url,
                source_edition=row.source_edition,
                territory=row.territory or "NG",
                coverage_status="partial",
            )
        )
    return usages, edition_rows


def _write_full_text_outputs(
    output_dir: Path,
    *,
    rows: list[PsalmSourceRow],
    douay_db: Path | None,
    retrieved_at: str,
) -> None:
    usages, editions = _full_text_corpus(rows, douay_db=douay_db)
    comparison = build_wide_comparison(
        usages,
        editions,
        baseline_edition="local_rsvce",
    )
    write_csv_rows(
        output_dir / "psalm_text_editions.csv",
        edition_text_rows(editions),
        fieldnames=EDITION_TEXT_FIELDS,
    )
    write_csv_rows(
        output_dir / "psalm_text_comparison.csv",
        comparison,
        fieldnames=wide_fieldnames(),
    )
    write_csv_rows(
        output_dir / "psalm_usage_map.csv",
        usage_rows(usages),
        fieldnames=USAGE_FIELDS,
    )
    counts = {
        edition_id: sum(
            1
            for row in editions
            if row.edition_id == edition_id and row.stanzas_text.strip()
        )
        for edition_id in sorted({row.edition_id for row in editions})
    }
    report = {
        "retrieved_at": retrieved_at,
        "selection_count": len(comparison),
        "usage_count": len(usages),
        "comparison_ready_count": sum(
            row["comparison_status"] == "comparison_ready" for row in comparison
        ),
        "insufficient_edition_count": sum(
            row["comparison_status"] == "insufficient_editions"
            for row in comparison
        ),
        "complete_selection_count_by_edition": counts,
    }
    _atomic_text(
        output_dir / "responsorial_psalm_audit_report.json",
        json.dumps(report, indent=2, sort_keys=True) + "\n",
    )


def build(
    *,
    output_dir: Path,
    refresh_live: bool,
    retrieved_at: str,
    full_text_output: Path | None = None,
    douay_db: Path | None = None,
) -> None:
    records = _registry()
    rows = load_local_psalm_rows(ROOT, retrieved_at=retrieved_at)
    if refresh_live:
        rows.extend(fetch_live_rows(retrieved_at=retrieved_at))
    else:
        fixture = json.loads(
            (
                ROOT
                / "test/fixtures/psalm_sources/nigeria_365_page.json"
            ).read_text(encoding="utf-8")
        )
        rows.extend(extract_rows(fixture, retrieved_at=retrieved_at))

    modern_html = (
        ROOT / "test/fixtures/psalm_sources/modern_psalter_118.html"
    ).read_text(encoding="utf-8")
    modern_metadata = parse_liturgy_page(
        modern_html,
        "https://www.modernpsalter.com/Lectionary.aspx?n=118",
    )
    compared = _compare_to_nigeria(rows)
    output_dir.mkdir(parents=True, exist_ok=True)
    _write_inventory(output_dir, records)
    _write_comparison(output_dir, compared)
    runtime_count = _write_runtime(output_dir, compared)
    _write_report(
        output_dir,
        records=records,
        rows=compared,
        runtime_count=runtime_count,
        modern_metadata=modern_metadata,
        retrieved_at=retrieved_at,
    )
    if full_text_output is not None:
        _write_full_text_outputs(
            full_text_output,
            rows=rows,
            douay_db=douay_db,
            retrieved_at=retrieved_at,
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--fixtures-only", action="store_true")
    mode.add_argument("--fixture-mode", action="store_true")
    mode.add_argument("--refresh-live", action="store_true")
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--full-text-output", type=Path)
    parser.add_argument("--douay-db", type=Path)
    parser.add_argument("--external-pack-dir", type=Path)
    parser.add_argument("--retrieved-at", default="2026-08-16")
    args = parser.parse_args()
    output_dir = args.output_dir or args.full_text_output
    if output_dir is None:
        parser.error("one of --output-dir or --full-text-output is required")
    build(
        output_dir=output_dir,
        refresh_live=args.refresh_live,
        retrieved_at=args.retrieved_at,
        full_text_output=args.full_text_output,
        douay_db=args.douay_db,
    )


if __name__ == "__main__":
    main()
