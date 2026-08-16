from __future__ import annotations

from dataclasses import asdict
import csv
from pathlib import Path
import tempfile
import os
from typing import Iterable, Mapping, Sequence

from .compare import classify_difference, similarity
from .models import PsalmEditionText, PsalmUsage


TARGET_EDITIONS = (
    "nigeria_365_firestore",
    "modern_psalter_us",
    "jerusalem_bible",
    "esvce",
    "local_rsvce",
    "local_nabre",
    "douay_rheims",
)


EDITION_TEXT_FIELDS = (
    "selection_id",
    "edition_id",
    "reference_normalized",
    "response_text",
    "stanzas_text",
    "source_url",
    "source_edition",
    "territory",
    "coverage_status",
    "missing_reason",
    "raw_sha256",
    "normalized_sha256",
)


USAGE_FIELDS = tuple(PsalmUsage.__dataclass_fields__)


def index_editions(
    rows: Iterable[PsalmEditionText],
) -> dict[tuple[str, str], PsalmEditionText]:
    indexed: dict[tuple[str, str], PsalmEditionText] = {}
    for row in rows:
        key = (row.selection_id, row.edition_id)
        previous = indexed.get(key)
        if previous is not None and previous.raw_sha256 != row.raw_sha256:
            raise ValueError(f"conflicting edition text for {key}")
        indexed[key] = row
    return indexed


def _complete(row: PsalmEditionText | None) -> bool:
    return row is not None and bool(row.stanzas_text.strip())


def _add_edition_columns(
    output: dict[str, object],
    edition_id: str,
    row: PsalmEditionText | None,
) -> None:
    output[f"{edition_id}_reference_normalized"] = (
        row.reference_normalized if row else ""
    )
    output[f"{edition_id}_response_text"] = row.response_text if row else ""
    output[f"{edition_id}_stanzas_text"] = row.stanzas_text if row else ""
    output[f"{edition_id}_source_url"] = row.source_url if row else ""
    output[f"{edition_id}_coverage_status"] = (
        row.coverage_status if row else "unavailable"
    )
    output[f"{edition_id}_missing_reason"] = (
        row.missing_reason if row else "edition text not installed"
    )
    output[f"{edition_id}_raw_sha256"] = row.raw_sha256 if row else ""
    output[f"{edition_id}_normalized_sha256"] = (
        row.normalized_sha256 if row else ""
    )


def build_wide_comparison(
    usages: Sequence[PsalmUsage],
    edition_rows: Sequence[PsalmEditionText],
    *,
    baseline_edition: str,
) -> list[dict[str, object]]:
    by_selection = index_editions(edition_rows)
    output_rows: list[dict[str, object]] = []
    for selection_id in sorted({usage.selection_id for usage in usages}):
        related = [usage for usage in usages if usage.selection_id == selection_id]
        baseline = by_selection.get((selection_id, baseline_edition))
        output: dict[str, object] = {
            "selection_id": selection_id,
            "usage_count": len(related),
            "territories": ";".join(sorted({row.territory for row in related})),
            "celebration_ids": ";".join(
                sorted({row.celebration_id for row in related if row.celebration_id})
            ),
        }
        complete = 0
        for edition_id in TARGET_EDITIONS:
            row = by_selection.get((selection_id, edition_id))
            _add_edition_columns(output, edition_id, row)
            if _complete(row):
                complete += 1
            if _complete(baseline) and _complete(row):
                baseline_text = (
                    f"{baseline.response_text}\n{baseline.stanzas_text}"
                )
                edition_text = f"{row.response_text}\n{row.stanzas_text}"
                output[f"{edition_id}_difference_class"] = classify_difference(
                    baseline_text, edition_text
                )
                output[f"{edition_id}_match_score"] = similarity(
                    baseline_text, edition_text
                )
            else:
                output[f"{edition_id}_difference_class"] = "missing_text"
                output[f"{edition_id}_match_score"] = ""
        output["complete_edition_count"] = complete
        output["comparison_status"] = (
            "comparison_ready" if complete >= 2 else "insufficient_editions"
        )
        output_rows.append(output)
    return output_rows


def edition_text_rows(rows: Iterable[PsalmEditionText]) -> list[dict[str, object]]:
    output = []
    for row in sorted(rows, key=lambda value: (value.selection_id, value.edition_id)):
        output.append(
            {
                "selection_id": row.selection_id,
                "edition_id": row.edition_id,
                "reference_normalized": row.reference_normalized,
                "response_text": row.response_text,
                "stanzas_text": row.stanzas_text,
                "source_url": row.source_url,
                "source_edition": row.source_edition,
                "territory": row.territory,
                "coverage_status": row.coverage_status,
                "missing_reason": row.missing_reason,
                "raw_sha256": row.raw_sha256,
                "normalized_sha256": row.normalized_sha256,
            }
        )
    return output


def usage_rows(rows: Iterable[PsalmUsage]) -> list[dict[str, object]]:
    return [
        asdict(row)
        for row in sorted(
            rows,
            key=lambda value: (
                value.selection_id,
                value.territory,
                value.usage_id,
            ),
        )
    ]


def wide_fieldnames() -> tuple[str, ...]:
    fields = ["selection_id", "usage_count", "territories", "celebration_ids"]
    for edition_id in TARGET_EDITIONS:
        fields.extend(
            (
                f"{edition_id}_reference_normalized",
                f"{edition_id}_response_text",
                f"{edition_id}_stanzas_text",
                f"{edition_id}_source_url",
                f"{edition_id}_coverage_status",
                f"{edition_id}_missing_reason",
                f"{edition_id}_raw_sha256",
                f"{edition_id}_normalized_sha256",
                f"{edition_id}_difference_class",
                f"{edition_id}_match_score",
            )
        )
    fields.extend(("complete_edition_count", "comparison_status"))
    return tuple(fields)


def write_csv_rows(
    path: Path,
    rows: Iterable[Mapping[str, object]],
    *,
    fieldnames: Sequence[str],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        newline="",
        delete=False,
        dir=path.parent,
    ) as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=fieldnames,
            extrasaction="ignore",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)
        temporary = Path(handle.name)
    os.replace(temporary, path)
