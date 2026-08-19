from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
from datetime import date, timedelta
import json
from pathlib import Path
import re
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from psalm_sources.bible_databases import extract_bible_selections, parse_selection
from psalm_sources.models import PsalmSourceRow
from psalm_sources.nigeria_365 import _psalm_sections
from psalm_sources.nigeria_archive import (
    HistoricalPsalmEvidence,
    parse_catholic_gallery_psalm,
    parse_catholic_leaf_psalm,
    parse_universalis_calendar,
    selection_reference,
    selection_signature,
)
from psalm_sources.nigeria_assignment_rules import infer_nigeria_assignments
from psalm_sources.normalize import normalize_reference, normalize_words, parse_responsorial_section


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "verification/psalm_sources"
START = date(2024, 1, 1)
END = date(2025, 11, 30)


def _dates() -> list[date]:
    output: list[date] = []
    cursor = START
    while cursor <= END:
        output.append(cursor)
        cursor += timedelta(days=1)
    return output


def _fetch_text(url: str, *, attempts: int = 3) -> str:
    request = Request(url, headers={"User-Agent": "CatholicDailyPsalmAudit/1.0"})
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            with urlopen(request, timeout=60) as response:
                return response.read().decode("utf-8", errors="replace")
        except Exception as error:  # noqa: BLE001 - evidence audit records gaps.
            last_error = error
            if attempt + 1 < attempts:
                time.sleep(0.5 * (attempt + 1))
    assert last_error is not None
    raise last_error


def _load_primary_samples() -> dict[str, HistoricalPsalmEvidence]:
    output: dict[str, HistoricalPsalmEvidence] = {}
    paths = (
        ROOT / "verification/official_missal_backward_audit.json",
        ROOT / "verification/official_missal_backward_retry_2025.json",
    )
    for path in paths:
        if not path.exists():
            continue
        for item in json.loads(path.read_text(encoding="utf-8-sig")):
            source_date = str(item.get("date", ""))
            psalm = item.get("psalm") or {}
            if not (START.isoformat() <= source_date <= END.isoformat() and psalm):
                continue
            reference = str(psalm.get("reference", "")).strip()
            response = re.sub(
                r"^R\s*/?\.\s*",
                "",
                str(psalm.get("response", "")).strip(),
                flags=re.I,
            )
            stanzas = ""
            sections = _psalm_sections(str(item.get("raw_excerpt", "")))
            if sections:
                try:
                    parsed = parse_responsorial_section(sections[0])
                    reference = parsed.reference_raw
                    response = parsed.response
                    stanzas = "\n\n".join(parsed.stanzas)
                except ValueError:
                    pass
            if reference and response:
                output[source_date] = HistoricalPsalmEvidence(
                    date_rule=source_date,
                    reference_raw=reference,
                    reference_normalized=normalize_reference(reference),
                    response_raw=response,
                    response_normalized=normalize_words(response),
                    stanzas_raw=stanzas,
                    stanzas_normalized=normalize_words(stanzas),
                    source_id="catholic_missal_daily_preserved_ui",
                    source_edition="Catholic Missal for Nigeria preserved UI capture",
                    source_url="https://play.google.com/store/apps/details?id=ng.com.hybridintegrated.a365dailyreadingsfornigeria",
                )
    return output


def _load_catholic_leaf() -> tuple[dict[str, HistoricalPsalmEvidence], dict[str, str]]:
    params = {
        "after": "2023-12-20T00:00:00",
        "before": "2025-12-08T23:59:59",
        "per_page": 100,
        "_fields": "date,link,title,content",
    }
    base = "https://www.catholicleaf.com/wp-json/wp/v2/posts"
    first_url = base + "?" + urlencode({**params, "page": 1})
    request = Request(first_url, headers={"User-Agent": "CatholicDailyPsalmAudit/1.0"})
    with urlopen(request, timeout=60) as response:
        pages = int(response.headers.get("X-WP-TotalPages", "1"))
        payloads = [json.load(response)]
    for page in range(2, pages + 1):
        payloads.append(json.loads(_fetch_text(base + "?" + urlencode({**params, "page": page}))))

    evidence: dict[str, HistoricalPsalmEvidence] = {}
    errors: dict[str, str] = {}
    for post in (item for payload in payloads for item in payload):
        url = str(post.get("link", ""))
        html = str((post.get("content") or {}).get("rendered", ""))
        try:
            row = parse_catholic_leaf_psalm(html, source_url=url)
        except ValueError as error:
            errors[url] = str(error)
            continue
        if START.isoformat() <= row.date_rule <= END.isoformat():
            evidence.setdefault(row.date_rule, row)
    return evidence, errors


def _gallery_url(day: date) -> str:
    return f"https://www.catholicgallery.org/mass-reading/{day:%d%m%y}/"


def _load_catholic_gallery() -> tuple[dict[str, HistoricalPsalmEvidence], dict[str, str]]:
    evidence: dict[str, HistoricalPsalmEvidence] = {}
    errors: dict[str, str] = {}

    def load(day: date) -> HistoricalPsalmEvidence:
        url = _gallery_url(day)
        return parse_catholic_gallery_psalm(_fetch_text(url), source_url=url)

    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(load, day): day for day in _dates()}
        completed = 0
        for future in as_completed(futures):
            day = futures[future]
            completed += 1
            try:
                evidence[day.isoformat()] = future.result()
            except Exception as error:  # noqa: BLE001 - inventory records exact gap.
                errors[day.isoformat()] = f"{type(error).__name__}: {error}"
            if completed % 100 == 0:
                print(f"Catholic Gallery: {completed}/700", flush=True)
    return evidence, errors


def _load_nigeria_calendars() -> dict[str, str]:
    output: dict[str, str] = {}
    for year in (2024, 2025):
        url = f"https://universalis.com/africa.nigeria/calendar-{year}.htm"
        output.update(parse_universalis_calendar(_fetch_text(url), year=year))
    return output


def _load_existing_evidence() -> tuple[
    dict[str, HistoricalPsalmEvidence],
    dict[str, HistoricalPsalmEvidence],
    dict[str, HistoricalPsalmEvidence],
]:
    path = OUTPUT_DIR / "nigeria_2024_2025_psalms.csv"
    sources: dict[str, dict[str, HistoricalPsalmEvidence]] = {
        "catholic_missal_daily_preserved_ui": {},
        "catholic_leaf_archive": {},
        "catholic_gallery_douay_archive": {},
    }
    with path.open(encoding="utf-8-sig", newline="") as handle:
        for item in csv.DictReader(handle):
            source_id = item["source_id"]
            if source_id not in sources:
                continue
            reference = item.get("reference_raw") or item["reference_normalized"]
            response = item["response_text"]
            stanzas = item["stanzas_text"]
            row = HistoricalPsalmEvidence(
                date_rule=item["source_date"],
                reference_raw=reference,
                reference_normalized=item["reference_normalized"],
                response_raw=response,
                response_normalized=normalize_words(response),
                stanzas_raw=stanzas,
                stanzas_normalized=normalize_words(stanzas),
                source_id=source_id,
                source_edition=item["source_edition"],
                source_url=item["source_url"],
            )
            sources[source_id][row.date_rule] = row
    return (
        sources["catholic_missal_daily_preserved_ui"],
        sources["catholic_leaf_archive"],
        sources["catholic_gallery_douay_archive"],
    )


def _load_existing_nigeria_calendar() -> dict[str, str]:
    path = OUTPUT_DIR / "nigeria_2024_2025_source_inventory.csv"
    if not path.exists():
        return {}
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return {
            item["date"]: item["nigeria_calendar_title"]
            for item in csv.DictReader(handle)
            if item["nigeria_calendar_status"] == "recovered"
        }


def _as_source_row(evidence: HistoricalPsalmEvidence) -> PsalmSourceRow:
    return PsalmSourceRow(
        usage_id=f"history:{evidence.source_id}:{evidence.date_rule}:1",
        celebration_id="",
        celebration_title="",
        date_rule=evidence.date_rule,
        season="",
        week="",
        weekday="",
        sunday_cycle="",
        weekday_cycle="",
        lectionary_number="",
        territory="NG",
        reading_set_kind="historical-verification",
        reading_set_priority=1,
        biblical_book="",
        psalm_number_hebrew="",
        psalm_number_vulgate="",
        reference_raw=evidence.reference_raw,
        reference_normalized=evidence.reference_normalized,
        stanza_selection_normalized=evidence.reference_normalized,
        response_verse_normalized="",
        source_id=evidence.source_id,
        source_name=evidence.source_edition,
        source_edition=evidence.source_edition,
        source_territory="NG",
        source_url=evidence.source_url,
        retrieved_at="2026-08-17",
        source_license="comparison evidence",
        reuse_status="comparison_only",
        response_raw=evidence.response_raw,
        response_normalized=evidence.response_normalized,
        stanzas_raw=evidence.stanzas_raw,
        stanzas_normalized=evidence.stanzas_normalized,
        raw_sha256="",
        normalized_sha256="",
        token_count=len(evidence.stanzas_normalized.split()),
    )


def _stable_key(assignment: object) -> str:
    kind = str(getattr(assignment, "kind"))
    if kind == "temporal":
        values = (
            "NG",
            kind,
            getattr(assignment, "season"),
            getattr(assignment, "week"),
            getattr(assignment, "weekday"),
            getattr(assignment, "sunday_cycle"),
            getattr(assignment, "weekday_cycle"),
        )
    elif kind == "celebration":
        values = (
            "NG",
            kind,
            getattr(assignment, "celebration_id"),
            getattr(assignment, "mass_form"),
            getattr(assignment, "sunday_cycle"),
            getattr(assignment, "weekday_cycle"),
        )
    else:
        values = (
            "NG",
            kind,
            getattr(assignment, "special_day"),
            getattr(assignment, "mass_form"),
            getattr(assignment, "sunday_cycle"),
            getattr(assignment, "weekday_cycle"),
        )
    return "|".join(str(value) for value in values)


def _write_csv(path: Path, fields: tuple[str, ...], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _reference_metrics(references: list[str]) -> dict[str, int]:
    exact: set[str] = set()
    numbered: set[tuple[tuple[str, int, tuple[int, ...]], ...]] = set()
    bases: set[tuple[str, int]] = set()
    for reference in references:
        selection = selection_reference(reference)
        parsed = parse_selection(selection)
        exact.add(parsed.normalized)
        signature = selection_signature(selection)
        numbered.add(signature)
        bases.update((book, chapter) for book, chapter, _ in signature)
    return {
        "unique_base_compositions": len(bases),
        "unique_exact_references": len(exact),
        "unique_numbered_verse_selections": len(numbered),
    }


def _current_runtime_references() -> list[str]:
    path = ROOT / "assets/data/nigeria_psalm_usages.csv"
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return [item["reference_normalized"] for item in csv.DictReader(handle)]


def _current_runtime_keys() -> set[str]:
    path = ROOT / "assets/data/nigeria_psalm_usages.csv"
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    keys: set[str] = set()
    for row in rows:
        if row["kind"] == "temporal":
            values = (
                row["territory"],
                row["kind"],
                row["season"],
                row["week"],
                row["weekday"],
                row["sunday_cycle"],
                row["weekday_cycle"],
            )
        elif row["kind"] == "celebration":
            values = (
                row["territory"],
                row["kind"],
                row["celebration_id"],
                row["mass_form"],
                row["sunday_cycle"],
                row["weekday_cycle"],
            )
        else:
            values = (
                row["territory"],
                row["kind"],
                row["special_day"],
                row["mass_form"],
                row["sunday_cycle"],
                row["weekday_cycle"],
            )
        keys.add("|".join(values))
    return keys


def build(*, from_existing: bool = False) -> dict[str, object]:
    if from_existing:
        primary, leaf, gallery = _load_existing_evidence()
        leaf_errors: dict[str, str] = {}
        gallery_errors: dict[str, str] = {}
        nigeria_calendar = _load_existing_nigeria_calendar()
    else:
        primary = _load_primary_samples()
        leaf, leaf_errors = _load_catholic_leaf()
        gallery, gallery_errors = _load_catholic_gallery()
        nigeria_calendar = _load_nigeria_calendars()
    print(f"Preserved primary dates: {len(primary)}", flush=True)
    print(f"Catholic Leaf dates: {len(leaf)}", flush=True)
    print(f"Catholic Gallery dates: {len(gallery)}", flush=True)
    print(f"Universalis Nigeria calendar dates: {len(nigeria_calendar)}", flush=True)

    evidence_rows: list[dict[str, object]] = []
    for source in (primary, leaf, gallery):
        for row in source.values():
            evidence_rows.append(
                {
                    "source_date": row.date_rule,
                    "source_id": row.source_id,
                    "source_edition": row.source_edition,
                    "source_url": row.source_url,
                    "reference_raw": row.reference_raw,
                    "reference_normalized": row.reference_normalized,
                    "response_text": row.response_raw,
                    "stanzas_text": row.stanzas_raw,
                }
            )
    evidence_rows.sort(key=lambda row: (str(row["source_date"]), str(row["source_id"])))
    _write_csv(
        OUTPUT_DIR / "nigeria_2024_2025_psalms.csv",
        (
            "source_date",
            "source_id",
            "source_edition",
            "source_url",
            "reference_raw",
            "reference_normalized",
            "response_text",
            "stanzas_text",
        ),
        evidence_rows,
    )

    candidates: list[PsalmSourceRow] = []
    candidate_dates: list[str] = []
    for day in _dates():
        iso = day.isoformat()
        candidate = primary.get(iso) or leaf.get(iso) or gallery.get(iso)
        if candidate is not None:
            candidates.append(_as_source_row(candidate))
            candidate_dates.append(iso)
    assignments, unresolved = infer_nigeria_assignments(candidates, root=ROOT)
    assignment_by_date = {
        source_date: assignment
        for source_date, assignment in zip(candidate_dates, assignments, strict=True)
    }

    comparisons: list[dict[str, object]] = []
    assignment_audit: list[dict[str, object]] = []
    inventory: list[dict[str, object]] = []
    base_compositions: set[str] = set()
    references: set[str] = set()
    reference_responses: set[tuple[str, str]] = set()
    full_texts: set[tuple[str, str, str]] = set()
    conflicts = 0
    notation_variants = 0
    runtime_keys = _current_runtime_keys()
    comparison_dates = [
        day.isoformat()
        for day in _dates()
        if gallery.get(day.isoformat()) is not None
        and (primary.get(day.isoformat()) or leaf.get(day.isoformat()) or gallery.get(day.isoformat()))
        is not None
    ]
    rsvce_rows = extract_bible_selections(
        ROOT / "assets/rsvce.db",
        edition_id="local_rsvce",
        selections=[
            (
                gallery[source_date].reference_raw,
                (primary.get(source_date) or leaf.get(source_date) or gallery[source_date]).response_raw,
            )
            for source_date in comparison_dates
        ],
        source_url="repo://assets/rsvce.db",
    )
    rsvce_by_date = dict(zip(comparison_dates, rsvce_rows, strict=True))
    for day in _dates():
        iso = day.isoformat()
        primary_row = primary.get(iso)
        leaf_row = leaf.get(iso)
        gallery_row = gallery.get(iso)
        available = [row for row in (primary_row, leaf_row, gallery_row) if row]
        candidate = primary_row or leaf_row or gallery_row
        verification = (
            "primary_recovered"
            if primary_row
            else "two_secondary_sources"
            if leaf_row and gallery_row
            else "one_secondary_source"
            if leaf_row or gallery_row
            else "unavailable"
        )
        inventory.append(
            {
                "date": iso,
                "primary_source_status": "recovered" if primary_row else "not_in_current_live_collection",
                "primary_source_url": primary_row.source_url if primary_row else "",
                "catholic_leaf_status": "recovered" if leaf_row else "unavailable",
                "catholic_leaf_url": leaf_row.source_url if leaf_row else "",
                "catholic_gallery_status": "recovered" if gallery_row else "unavailable",
                "catholic_gallery_url": gallery_row.source_url if gallery_row else _gallery_url(day),
                "nigeria_calendar_status": "recovered" if iso in nigeria_calendar else "unavailable",
                "nigeria_calendar_title": nigeria_calendar.get(iso, ""),
                "verification_status": verification,
                "notes": "" if available else "No recoverable dated psalm evidence",
            }
        )
        if candidate is None or gallery_row is None:
            continue
        assignment = assignment_by_date[iso]
        rsvce = rsvce_by_date[iso]
        gallery_full = gallery_row.response_raw + "\n\n" + gallery_row.stanzas_raw
        rsvce_full = rsvce.response_text + "\n\n" + rsvce.stanzas_text
        refs = {selection_reference(row.reference_normalized) for row in available}
        signatures = {selection_signature(row.reference_normalized) for row in available}
        responses = {row.response_normalized for row in available}
        if len(refs) == 1 and len(responses) == 1:
            status = "reference_and_response_match"
        elif len(refs) == 1:
            status = "reference_match_translation_response"
        elif len(signatures) == 1:
            status = "same_numbered_verses_reference_variant"
            notation_variants += 1
        else:
            status = "reference_conflict"
            conflicts += 1
        reference = selection_reference(candidate.reference_normalized)
        base_compositions.add(reference.split(":", maxsplit=1)[0])
        references.add(reference)
        reference_responses.add((reference, candidate.response_normalized))
        full_texts.add((reference, candidate.response_normalized, normalize_words(gallery_row.stanzas_raw)))
        stable_key = _stable_key(assignment)
        key_status = "existing_runtime_key" if stable_key in runtime_keys else "new_runtime_key"
        reconciliation_status = (
            "conflict_review_required"
            if status == "reference_conflict"
            else "corroborates_runtime_key"
            if key_status == "existing_runtime_key"
            else "new_usage_candidate"
        )
        assignment_audit.append(
            {
                "source_date": iso,
                "reference_source_id": gallery_row.source_id,
                "response_source_id": candidate.source_id,
                "source_selection_id": f"history:reconciled:{iso}:1",
                "stable_usage_key": stable_key,
                "kind": assignment.kind,
                "celebration_id": assignment.celebration_id,
                "mass_form": assignment.mass_form,
                "season": assignment.season,
                "week": assignment.week,
                "weekday": assignment.weekday,
                "special_day": assignment.special_day,
                "sunday_cycle": assignment.sunday_cycle,
                "weekday_cycle": assignment.weekday_cycle,
                "selected_reference": selection_reference(
                    gallery_row.reference_normalized
                ),
                "selected_response": candidate.response_raw,
                "comparison_status": status,
                "key_status": key_status,
                "reconciliation_status": reconciliation_status,
            }
        )
        comparisons.append(
            {
                "source_date": iso,
                "stable_usage_key": stable_key,
                "liturgical_kind": assignment.kind,
                "celebration_id": assignment.celebration_id,
                "mass_form": assignment.mass_form,
                "season": assignment.season,
                "week": assignment.week,
                "weekday": assignment.weekday,
                "sunday_cycle": assignment.sunday_cycle,
                "weekday_cycle": assignment.weekday_cycle,
                "nigeria_calendar_title": nigeria_calendar.get(iso, ""),
                "primary_reference": primary_row.reference_normalized if primary_row else "",
                "primary_response": primary_row.response_raw if primary_row else "",
                "leaf_reference": leaf_row.reference_normalized if leaf_row else "",
                "leaf_response": leaf_row.response_raw if leaf_row else "",
                "gallery_reference": gallery_row.reference_normalized,
                "gallery_response": gallery_row.response_raw,
                "douay_rheims_full_text": gallery_full,
                "rsvce_full_text": rsvce_full,
                "comparison_status": status,
            }
        )

    _write_csv(
        OUTPUT_DIR / "nigeria_2024_2025_source_inventory.csv",
        tuple(inventory[0]),
        inventory,
    )
    comparison_fields = (
        "source_date",
        "stable_usage_key",
        "liturgical_kind",
        "celebration_id",
        "mass_form",
        "season",
        "week",
        "weekday",
        "sunday_cycle",
        "weekday_cycle",
        "nigeria_calendar_title",
        "primary_reference",
        "primary_response",
        "leaf_reference",
        "leaf_response",
        "gallery_reference",
        "gallery_response",
        "douay_rheims_full_text",
        "rsvce_full_text",
        "comparison_status",
    )
    _write_csv(
        OUTPUT_DIR / "nigeria_2024_2025_comparison.csv",
        comparison_fields,
        comparisons,
    )
    _write_csv(
        OUTPUT_DIR / "nigeria_2024_2025_usage_assignments.csv",
        tuple(assignment_audit[0]),
        assignment_audit,
    )
    new_candidate_keys = {
        str(row["stable_usage_key"])
        for row in assignment_audit
        if row["reconciliation_status"] == "new_usage_candidate"
    }
    corroborated_keys = {
        str(row["stable_usage_key"])
        for row in assignment_audit
        if row["reconciliation_status"] == "corroborates_runtime_key"
    }
    conflict_keys = {
        str(row["stable_usage_key"])
        for row in assignment_audit
        if row["reconciliation_status"] == "conflict_review_required"
    }
    coverage = {
        "range": {"start": START.isoformat(), "end": END.isoformat(), "dates": len(_dates())},
        "primary_recovered_dates": len(primary),
        "catholic_leaf_recovered_dates": len(leaf),
        "catholic_gallery_recovered_dates": len(gallery),
        "nigeria_calendar_dates": len(nigeria_calendar),
        "comparison_rows_with_two_full_texts": len(comparisons),
        "reference_conflicts": conflicts,
        "reference_notation_variants": notation_variants,
        "unresolved_assignments": unresolved,
        "unique_base_compositions": len(base_compositions),
        "unique_references": len(references),
        "unique_reference_response_pairs": len(reference_responses),
        "unique_full_text_forms": len(full_texts),
        "leaf_parse_failures": len(leaf_errors),
        "gallery_failures": len(gallery_errors),
        "gallery_failure_dates": gallery_errors,
        "historical_unique_stable_keys": len(
            {str(row["stable_usage_key"]) for row in assignment_audit}
        ),
        "new_usage_candidate_keys": len(new_candidate_keys),
        "corroborated_runtime_keys": len(corroborated_keys),
        "conflict_review_dates": sum(
            row["reconciliation_status"] == "conflict_review_required"
            for row in assignment_audit
        ),
        "conflict_review_keys": len(conflict_keys),
        "reference_counts": {
            "current_runtime_2025_2026": _reference_metrics(
                _current_runtime_references()
            ),
            "catholic_leaf_2024_2025": _reference_metrics(
                [row.reference_normalized for row in leaf.values()]
            ),
            "catholic_gallery_2024_2025": _reference_metrics(
                [row.reference_normalized for row in gallery.values()]
            ),
            "combined_runtime_and_gallery": _reference_metrics(
                _current_runtime_references()
                + [row.reference_normalized for row in gallery.values()]
            ),
        },
    }
    (OUTPUT_DIR / "nigeria_2024_2025_coverage.json").write_text(
        json.dumps(coverage, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return coverage


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--from-existing",
        action="store_true",
        help="Rebuild comparisons from the saved evidence CSV without recrawling sources.",
    )
    args = parser.parse_args()
    coverage = build(from_existing=args.from_existing)
    print(json.dumps(coverage, ensure_ascii=False, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
