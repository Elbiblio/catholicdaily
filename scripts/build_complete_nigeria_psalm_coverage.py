from __future__ import annotations

import argparse
from collections import Counter
import csv
import hashlib
import io
import json
from pathlib import Path
import tempfile

if __package__:
    from scripts.psalm_sources.liturgical_usage_universe import (
        LiturgicalUsageTarget,
        build_liturgical_usage_universe,
        normalize_selection_reference,
        validate_liturgical_usage_universe,
    )
    from scripts.psalm_sources.normalize import normalize_words
    from scripts.psalm_sources.bible_databases import extract_bible_selections
    from scripts.psalm_sources.nigeria_text_reconstruction import (
        build_verified_fragment_index,
        reconstruct_nigeria_selection,
    )
    from scripts.psalm_sources.source_packs import PACK_FIELDS, RuntimePsalmPackRow
else:
    from psalm_sources.liturgical_usage_universe import (
        LiturgicalUsageTarget,
        build_liturgical_usage_universe,
        normalize_selection_reference,
        validate_liturgical_usage_universe,
    )
    from psalm_sources.normalize import normalize_words
    from psalm_sources.bible_databases import extract_bible_selections
    from psalm_sources.nigeria_text_reconstruction import (
        build_verified_fragment_index,
        reconstruct_nigeria_selection,
    )
    from psalm_sources.source_packs import PACK_FIELDS, RuntimePsalmPackRow


ROOT = Path(__file__).resolve().parents[1]
COVERAGE_CSV = (
    ROOT
    / "verification/psalm_sources/nigeria_complete_liturgical_coverage.csv"
)
COVERAGE_JSON = (
    ROOT
    / "verification/psalm_sources/nigeria_complete_liturgical_coverage.json"
)
COMPARISON_CSV = (
    ROOT
    / "verification/psalm_sources/nigeria_complete_psalm_text_comparison.csv"
)
NIGERIA_PACK = ROOT / "assets/data/psalm_editions/nigeria_365.csv"
MANIFEST = ROOT / "assets/data/psalm_editions/manifest.json"

COVERAGE_FIELDS = (
    "stable_usage_key",
    "choice_priority",
    "territory",
    "kind",
    "celebration_id",
    "mass_form",
    "season",
    "week",
    "weekday",
    "special_day",
    "sunday_cycle",
    "weekday_cycle",
    "lectionary_number",
    "reference_normalized",
    "response_text",
    "source_catalog",
    "nigeria_selection_id",
    "nigeria_source_date",
    "gallery_source_url",
    "gallery_text_edition",
    "rsvce_selection_id",
    "text_source_id",
    "display_edition",
    "resolution_status",
    "review_notes",
)

COMPARISON_FIELDS = (
    "stable_usage_key",
    "choice_priority",
    "reference_normalized",
    "response_text",
    "resolution_status",
    "display_edition",
    "nigeria_selection_id",
    "nigeria_text",
    "nigeria_source_url",
    "rsvce_selection_id",
    "rsvce_text",
    "rsvce_source_url",
    "nabre_selection_id",
    "nabre_text",
    "nabre_source_url",
    "douay_rheims_text",
    "douay_rheims_source_url",
)


def load_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def load_nigeria_pack(path: Path) -> list[RuntimePsalmPackRow]:
    return [
        RuntimePsalmPackRow(
            edition_id=row["edition_id"],
            selection_id=row["selection_id"],
            territory=row["territory"],
            celebration_id=row["celebration_id"],
            date_rule=row["date_rule"],
            reading_set_kind=row["reading_set_kind"],
            sunday_cycle=row["sunday_cycle"],
            weekday_cycle=row["weekday_cycle"],
            lectionary_number=row["lectionary_number"],
            reference_normalized=normalize_selection_reference(
                row["reference_normalized"]
            ),
            response_text=row["response_text"],
            stanzas_text=row["stanzas_text"],
            source_url=row["source_url"],
            source_edition=row["source_edition"],
            display_priority=int(row["display_priority"]),
        )
        for row in load_csv_rows(path)
    ]


def _stable_key_from_row(row: dict[str, str]) -> str:
    kind = row["kind"].replace("_", "-")
    if kind == "temporal":
        values = (
            row.get("territory", "NG") or "NG",
            kind,
            row["season"],
            row["week"],
            row["weekday"],
            row["sunday_cycle"],
            row["weekday_cycle"],
        )
    elif kind == "celebration":
        values = (
            row.get("territory", "NG") or "NG",
            kind,
            row["celebration_id"],
            row["mass_form"],
            row["sunday_cycle"],
            row["weekday_cycle"],
        )
    else:
        values = (
            row.get("territory", "NG") or "NG",
            kind,
            row["special_day"],
            row["mass_form"],
            row["sunday_cycle"],
            row["weekday_cycle"],
        )
    return "|".join(values)


def _pack_indexes(
    rows: list[RuntimePsalmPackRow],
) -> tuple[
    dict[tuple[str, str], list[RuntimePsalmPackRow]],
    dict[str, list[RuntimePsalmPackRow]],
]:
    exact: dict[tuple[str, str], list[RuntimePsalmPackRow]] = {}
    by_reference: dict[str, list[RuntimePsalmPackRow]] = {}
    for row in rows:
        reference = normalize_selection_reference(row.reference_normalized)
        response = normalize_words(row.response_text)
        exact.setdefault((reference, response), []).append(row)
        by_reference.setdefault(reference, []).append(row)
    for values in (*exact.values(), *by_reference.values()):
        values.sort(key=lambda row: (row.display_priority, row.selection_id))
    return exact, by_reference


def _history_and_gallery() -> tuple[
    dict[str, list[dict[str, str]]],
    dict[str, list[dict[str, str]]],
]:
    history_path = (
        ROOT
        / "verification/psalm_sources/nigeria_2024_2025_usage_assignments.csv"
    )
    evidence_path = (
        ROOT / "verification/psalm_sources/nigeria_2024_2025_psalms.csv"
    )
    history_by_key: dict[str, list[dict[str, str]]] = {}
    if history_path.exists():
        for row in load_csv_rows(history_path):
            history_by_key.setdefault(row["stable_usage_key"], []).append(row)
    gallery_by_date: dict[str, list[dict[str, str]]] = {}
    if evidence_path.exists():
        for row in load_csv_rows(evidence_path):
            if row["source_id"] != "catholic_gallery_douay_archive":
                continue
            gallery_by_date.setdefault(row["source_date"], []).append(row)
    return history_by_key, gallery_by_date


def _gallery_evidence(
    target: LiturgicalUsageTarget,
    history_by_key: dict[str, list[dict[str, str]]],
    gallery_by_date: dict[str, list[dict[str, str]]],
) -> dict[str, str] | None:
    for assignment in history_by_key.get(target.stable_key, ()):
        if normalize_selection_reference(assignment["selected_reference"]) != target.reference_normalized:
            continue
        for evidence in gallery_by_date.get(assignment["source_date"], ()):
            if normalize_selection_reference(evidence["reference_normalized"]) == target.reference_normalized:
                return evidence
    return None


def _coverage_row(
    target: LiturgicalUsageTarget,
    nigeria_exact: dict[tuple[str, str], list[RuntimePsalmPackRow]],
    rsvce_exact: dict[tuple[str, str], list[RuntimePsalmPackRow]],
    rsvce_by_reference: dict[str, list[RuntimePsalmPackRow]],
    history_by_key: dict[str, list[dict[str, str]]],
    gallery_by_date: dict[str, list[dict[str, str]]],
) -> dict[str, object]:
    response_key = normalize_words(target.response_text)
    exact_nigeria = nigeria_exact.get(
        (target.reference_normalized, response_key),
        (),
    )
    exact_rsvce = rsvce_exact.get(
        (target.reference_normalized, response_key),
        (),
    )
    reference_rsvce = rsvce_by_reference.get(target.reference_normalized, ())
    gallery = _gallery_evidence(target, history_by_key, gallery_by_date)

    nigeria = exact_nigeria[0] if exact_nigeria else None
    rsvce = exact_rsvce[0] if exact_rsvce else (
        reference_rsvce[0] if reference_rsvce else None
    )
    if nigeria is not None and nigeria.source_edition == "verified Nigerian fragments":
        text_source_id = "nigeria_365_firestore"
        display_edition = "Catholic Missal for Nigeria"
        status = "reconstructed_nigeria"
        notes = "Reconstructed only from exact verified Nigerian stanza fragments."
    elif nigeria is not None:
        text_source_id = "nigeria_365_firestore"
        display_edition = "Catholic Missal for Nigeria"
        status = "exact_nigeria"
        notes = "Exact Nigerian reference and response match."
    elif rsvce is not None:
        text_source_id = "local_rsvce"
        display_edition = "Catholic Daily RSVCE"
        status = "fallback"
        notes = "Nigerian wording unavailable; RSVCE remains explicitly labeled."
    elif gallery is not None and gallery["stanzas_text"].strip():
        text_source_id = "catholic_gallery_douay_archive"
        display_edition = "Douay-Rheims"
        status = "fallback"
        notes = "CatholicGallery supplies dated Douay-Rheims comparison text."
    else:
        text_source_id = ""
        display_edition = ""
        status = "missing"
        notes = "No installed full-text edition matches this selection."

    return {
        "stable_usage_key": target.stable_key,
        "choice_priority": target.choice_priority,
        "territory": target.territory,
        "kind": target.kind,
        "celebration_id": target.celebration_id,
        "mass_form": target.mass_form,
        "season": target.season,
        "week": target.week,
        "weekday": target.weekday,
        "special_day": target.special_day,
        "sunday_cycle": target.sunday_cycle,
        "weekday_cycle": target.weekday_cycle,
        "lectionary_number": target.lectionary_number,
        "reference_normalized": target.reference_normalized,
        "response_text": target.response_text,
        "source_catalog": target.source_catalog,
        "nigeria_selection_id": nigeria.selection_id if nigeria else "",
        "nigeria_source_date": nigeria.date_rule if nigeria else "",
        "gallery_source_url": gallery["source_url"] if gallery else "",
        "gallery_text_edition": "Douay-Rheims" if gallery else "",
        "rsvce_selection_id": rsvce.selection_id if rsvce else "",
        "text_source_id": text_source_id,
        "display_edition": display_edition,
        "resolution_status": status,
        "review_notes": notes,
    }


def build_coverage_rows(
    *,
    universe: tuple[LiturgicalUsageTarget, ...] | None = None,
    nigeria: list[RuntimePsalmPackRow] | None = None,
    rsvce: list[RuntimePsalmPackRow] | None = None,
) -> list[dict[str, object]]:
    universe = universe or validate_liturgical_usage_universe(
        build_liturgical_usage_universe(ROOT)
    )
    nigeria = nigeria or load_nigeria_pack(NIGERIA_PACK)
    rsvce = rsvce or load_nigeria_pack(
        ROOT / "assets/data/psalm_editions/rsvce.csv"
    )
    nigeria_exact, _ = _pack_indexes(nigeria)
    rsvce_exact, rsvce_by_reference = _pack_indexes(rsvce)
    history_by_key, gallery_by_date = _history_and_gallery()
    return [
        _coverage_row(
            target,
            nigeria_exact,
            rsvce_exact,
            rsvce_by_reference,
            history_by_key,
            gallery_by_date,
        )
        for target in universe
    ]


def _expanded_nigeria_pack(
    universe: tuple[LiturgicalUsageTarget, ...],
    existing: list[RuntimePsalmPackRow],
) -> list[RuntimePsalmPackRow]:
    primary = [
        row
        for row in existing
        if row.source_edition != "verified Nigerian fragments"
    ]
    fragments = build_verified_fragment_index(primary)
    existing_choices = {
        (
            normalize_selection_reference(row.reference_normalized),
            normalize_words(row.response_text),
        )
        for row in primary
    }
    required: dict[tuple[str, str], LiturgicalUsageTarget] = {}
    for target in universe:
        key = (target.reference_normalized, normalize_words(target.response_text))
        required.setdefault(key, target)

    reconstructed: list[RuntimePsalmPackRow] = []
    for key, target in sorted(required.items()):
        if key in existing_choices:
            continue
        resolution = reconstruct_nigeria_selection(
            target.reference_normalized,
            target.response_text,
            primary,
            fragments,
        )
        if resolution.status != "reconstructed_nigeria":
            continue
        digest = hashlib.sha1(
            f"{target.reference_normalized}|{normalize_words(target.response_text)}".encode(
                "utf-8"
            )
        ).hexdigest()[:16]
        reconstructed.append(
            RuntimePsalmPackRow(
                edition_id="nigeria_365_firestore",
                selection_id=f"ng:reconstructed:{digest}",
                territory="NG",
                celebration_id="",
                date_rule="",
                reading_set_kind="reconstructed-selection",
                sunday_cycle="",
                weekday_cycle="",
                lectionary_number=target.lectionary_number,
                reference_normalized=target.reference_normalized,
                response_text=target.response_text,
                stanzas_text=resolution.stanzas_text,
                source_url=(
                    "repo://verification/psalm_sources/"
                    "nigeria_complete_liturgical_coverage.csv"
                ),
                source_edition="verified Nigerian fragments",
                display_priority=20,
            )
        )
    return sorted(
        (*primary, *reconstructed),
        key=lambda row: (row.selection_id, row.display_priority),
    )


def _csv_text(rows: list[dict[str, object]]) -> str:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=COVERAGE_FIELDS)
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def _pack_csv_text(rows: list[RuntimePsalmPackRow]) -> str:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=PACK_FIELDS)
    writer.writeheader()
    writer.writerows(row.to_dict() for row in rows)
    return output.getvalue()


def _formatted_text(response: str, stanzas: str) -> str:
    blocks = tuple(
        block.strip()
        for block in stanzas.replace("\r\n", "\n").split("\n\n")
        if block.strip()
    )
    refrain = f"R/. {response.strip()}"
    return "\n\n".join(
        (refrain, *(part for stanza in blocks for part in (stanza, refrain)))
    )


def _extract_missing_bible_texts(
    database: Path,
    edition_id: str,
    selections: list[tuple[str, str]],
) -> tuple[dict[str, tuple[str, str]], dict[str, str]]:
    extracted: dict[str, tuple[str, str]] = {}
    errors: dict[str, str] = {}

    def extract_batch(batch: list[tuple[str, str]]) -> None:
        if not batch:
            return
        try:
            rows = extract_bible_selections(
                database,
                edition_id=edition_id,
                selections=batch,
                source_url=f"repo://{database.as_posix()}",
            )
        except (LookupError, ValueError) as error:
            if len(batch) == 1:
                errors[batch[0][0]] = str(error)
                return
            midpoint = len(batch) // 2
            extract_batch(batch[:midpoint])
            extract_batch(batch[midpoint:])
            return
        for (reference, _), row in zip(batch, rows, strict=True):
            extracted[reference] = (row.stanzas_text, row.source_url)

    extract_batch(selections)
    return extracted, errors


def _expanded_bible_pack(
    *,
    edition_id: str,
    database: Path,
    existing: list[RuntimePsalmPackRow],
    universe: tuple[LiturgicalUsageTarget, ...],
) -> list[RuntimePsalmPackRow]:
    primary = [
        row
        for row in existing
        if row.source_edition != "complete liturgical usage expansion"
    ]
    existing_references = {
        normalize_selection_reference(row.reference_normalized) for row in primary
    }
    required = {
        target.reference_normalized: target.response_text for target in universe
    }
    missing = sorted(
        (reference, response)
        for reference, response in required.items()
        if reference not in existing_references
    )
    extracted, errors = _extract_missing_bible_texts(
        database, edition_id, missing
    )
    if errors:
        raise ValueError(
            f"unresolved {edition_id} runtime references:\n"
            + "\n".join(f"{key}: {value}" for key, value in errors.items())
        )
    territory = "US" if edition_id == "local_nabre" else "WORLD"
    expanded = [
        RuntimePsalmPackRow(
            edition_id=edition_id,
            selection_id=(
                f"{edition_id}:expanded:"
                + hashlib.sha1(reference.encode("utf-8")).hexdigest()[:16]
            ),
            territory=territory,
            celebration_id="",
            date_rule="",
            reading_set_kind="generic",
            sunday_cycle="",
            weekday_cycle="",
            lectionary_number="",
            reference_normalized=reference,
            response_text=response,
            stanzas_text=extracted[reference][0],
            source_url=extracted[reference][1],
            source_edition="complete liturgical usage expansion",
            display_priority=110,
        )
        for reference, response in missing
    ]
    return sorted(
        (*primary, *expanded),
        key=lambda row: (row.selection_id, row.display_priority),
    )


def _comparison_rows(
    coverage: list[dict[str, object]],
    nigeria: list[RuntimePsalmPackRow],
    rsvce: list[RuntimePsalmPackRow],
    nabre: list[RuntimePsalmPackRow],
) -> list[dict[str, object]]:
    nigeria_by_id = {row.selection_id: row for row in nigeria}
    rsvce_by_id = {row.selection_id: row for row in rsvce}
    rsvce_by_reference = {
        normalize_selection_reference(row.reference_normalized): row
        for row in rsvce
    }
    nabre_by_reference = {
        normalize_selection_reference(row.reference_normalized): row
        for row in nabre
    }
    gallery_by_url_reference = {
        (row["source_url"], normalize_selection_reference(row["reference_normalized"])): row
        for row in load_csv_rows(
            ROOT / "verification/psalm_sources/nigeria_2024_2025_psalms.csv"
        )
        if row["source_id"] == "catholic_gallery_douay_archive"
    }

    required = {
        str(row["reference_normalized"]): str(row["response_text"])
        for row in coverage
    }
    missing_rsvce = sorted(
        (reference, response)
        for reference, response in required.items()
        if reference not in rsvce_by_reference
    )
    missing_nabre = sorted(
        (reference, response)
        for reference, response in required.items()
        if reference not in nabre_by_reference
    )
    extracted_rsvce, rsvce_errors = _extract_missing_bible_texts(
        ROOT / "assets/rsvce.db", "local_rsvce", missing_rsvce
    )
    extracted_nabre, nabre_errors = _extract_missing_bible_texts(
        ROOT / "assets/nabre.db", "local_nabre", missing_nabre
    )
    if rsvce_errors or nabre_errors:
        problems = [
            *(f"RSVCE {key}: {value}" for key, value in rsvce_errors.items()),
            *(f"NABRE {key}: {value}" for key, value in nabre_errors.items()),
        ]
        raise ValueError("unresolved full-text comparison references:\n" + "\n".join(problems))

    output: list[dict[str, object]] = []
    for row in coverage:
        reference = str(row["reference_normalized"])
        response = str(row["response_text"])
        nigeria_row = nigeria_by_id.get(str(row["nigeria_selection_id"]))
        rsvce_row = rsvce_by_id.get(str(row["rsvce_selection_id"]))
        if rsvce_row is None:
            rsvce_row = rsvce_by_reference.get(reference)
        nabre_row = nabre_by_reference.get(reference)
        rsvce_text, rsvce_url = (
            (rsvce_row.stanzas_text, rsvce_row.source_url)
            if rsvce_row is not None
            else extracted_rsvce[reference]
        )
        nabre_text, nabre_url = (
            (nabre_row.stanzas_text, nabre_row.source_url)
            if nabre_row is not None
            else extracted_nabre[reference]
        )
        gallery = gallery_by_url_reference.get(
            (str(row["gallery_source_url"]), reference)
        )
        output.append(
            {
                "stable_usage_key": row["stable_usage_key"],
                "choice_priority": row["choice_priority"],
                "reference_normalized": reference,
                "response_text": response,
                "resolution_status": row["resolution_status"],
                "display_edition": row["display_edition"],
                "nigeria_selection_id": row["nigeria_selection_id"],
                "nigeria_text": _formatted_text(response, nigeria_row.stanzas_text)
                if nigeria_row is not None
                else "",
                "nigeria_source_url": nigeria_row.source_url
                if nigeria_row is not None
                else "",
                "rsvce_selection_id": rsvce_row.selection_id
                if rsvce_row is not None
                else "extracted:" + reference,
                "rsvce_text": _formatted_text(response, rsvce_text),
                "rsvce_source_url": rsvce_url,
                "nabre_selection_id": nabre_row.selection_id
                if nabre_row is not None
                else "extracted:" + reference,
                "nabre_text": _formatted_text(response, nabre_text),
                "nabre_source_url": nabre_url,
                "douay_rheims_text": _formatted_text(
                    response, gallery["stanzas_text"]
                )
                if gallery is not None and gallery["stanzas_text"].strip()
                else "",
                "douay_rheims_source_url": gallery["source_url"]
                if gallery is not None
                else "",
            }
        )
    return output


def _comparison_csv_text(rows: list[dict[str, object]]) -> str:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=COMPARISON_FIELDS)
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def _manifest_text(selection_counts: dict[str, int]) -> str:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    found_nigeria = False
    for edition in manifest["editions"]:
        edition_id = edition["id"]
        if edition_id in selection_counts:
            edition["selectionCount"] = selection_counts[edition_id]
        if edition_id == "nigeria_365_firestore":
            edition["displayName"] = "Catholic Missal for Nigeria"
            found_nigeria = True
    if not found_nigeria:
        raise ValueError("Nigeria edition is absent from the psalm manifest")
    return json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"


def _summary(rows: list[dict[str, object]]) -> dict[str, object]:
    statuses = Counter(str(row["resolution_status"]) for row in rows)
    return {
        "schema_version": 1,
        "stable_usages": len({str(row["stable_usage_key"]) for row in rows}),
        "ordered_choices": len(rows),
        "distinct_references": len(
            {str(row["reference_normalized"]) for row in rows}
        ),
        "distinct_responses": len({str(row["response_text"]) for row in rows}),
        "status_counts": dict(sorted(statuses.items())),
    }


def _atomic_write(path: Path, text: str) -> None:
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
    temporary.replace(path)


def _read_exact(path: Path) -> str:
    with path.open(encoding="utf-8", newline="") as handle:
        return handle.read()


def generate(*, check: bool = False) -> dict[str, object]:
    universe = validate_liturgical_usage_universe(
        build_liturgical_usage_universe(ROOT)
    )
    existing = load_nigeria_pack(NIGERIA_PACK)
    nigeria_pack = _expanded_nigeria_pack(universe, existing)
    rsvce_pack = _expanded_bible_pack(
        edition_id="local_rsvce",
        database=ROOT / "assets/rsvce.db",
        existing=load_nigeria_pack(
            ROOT / "assets/data/psalm_editions/rsvce.csv"
        ),
        universe=universe,
    )
    nabre_pack = _expanded_bible_pack(
        edition_id="local_nabre",
        database=ROOT / "assets/nabre.db",
        existing=load_nigeria_pack(
            ROOT / "assets/data/psalm_editions/nabre.csv"
        ),
        universe=universe,
    )
    rows = build_coverage_rows(
        universe=universe, nigeria=nigeria_pack, rsvce=rsvce_pack
    )
    comparison = _comparison_rows(
        rows, nigeria_pack, rsvce_pack, nabre_pack
    )
    csv_text = _csv_text(rows)
    comparison_text = _comparison_csv_text(comparison)
    pack_text = _pack_csv_text(nigeria_pack)
    rsvce_pack_text = _pack_csv_text(rsvce_pack)
    nabre_pack_text = _pack_csv_text(nabre_pack)
    manifest_text = _manifest_text(
        {
            "nigeria_365_firestore": len(nigeria_pack),
            "local_rsvce": len(rsvce_pack),
            "local_nabre": len(nabre_pack),
        }
    )
    summary = _summary(rows)
    json_text = json.dumps(summary, ensure_ascii=False, indent=2) + "\n"
    if check:
        expected = {
            NIGERIA_PACK: pack_text,
            ROOT / "assets/data/psalm_editions/rsvce.csv": rsvce_pack_text,
            ROOT / "assets/data/psalm_editions/nabre.csv": nabre_pack_text,
            COVERAGE_CSV: csv_text,
            COVERAGE_JSON: json_text,
            COMPARISON_CSV: comparison_text,
            MANIFEST: manifest_text,
        }
        stale = [
            str(path.relative_to(ROOT))
            for path, text in expected.items()
            if not path.exists() or _read_exact(path) != text
        ]
        if stale:
            raise SystemExit("stale Nigeria coverage artifacts: " + ", ".join(stale))
    else:
        _atomic_write(NIGERIA_PACK, pack_text)
        _atomic_write(
            ROOT / "assets/data/psalm_editions/rsvce.csv", rsvce_pack_text
        )
        _atomic_write(
            ROOT / "assets/data/psalm_editions/nabre.csv", nabre_pack_text
        )
        _atomic_write(COVERAGE_CSV, csv_text)
        _atomic_write(COVERAGE_JSON, json_text)
        _atomic_write(COMPARISON_CSV, comparison_text)
        _atomic_write(MANIFEST, manifest_text)
    return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    summary = generate(check=args.check)
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
