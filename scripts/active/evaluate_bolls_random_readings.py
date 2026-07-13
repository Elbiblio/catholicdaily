#!/usr/bin/env python3
"""Evaluate Bolls API against bundled Bible DBs for random reading references."""

from __future__ import annotations

import argparse
import csv
import json
import random
import re
from pathlib import Path

import probe_public_bible_apis as probe


DEFAULT_SAMPLE_SIZE = 24
DEFAULT_SEED = 20260713


def load_references(paths: list[Path]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    seen = set()
    for path in paths:
        with path.open("r", encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                for slot, field in (
                    ("first", "first_reading"),
                    ("second", "second_reading"),
                    ("gospel", "gospel"),
                ):
                    reference = normalize_reference(row.get(field, ""))
                    if not reference:
                        continue
                    key = (slot, reference)
                    if key in seen:
                        continue
                    seen.add(key)
                    rows.append(
                        {
                            "slot": slot,
                            "reference": reference,
                            "season": row.get("season", ""),
                            "week": row.get("week", ""),
                            "day": row.get("day", ""),
                            "sourcePath": str(path),
                        }
                    )
    return rows


def normalize_reference(value: str) -> str:
    text = " ".join((value or "").split())
    if not text:
        return ""
    text = re.sub(r"\bor\b.*$", "", text, flags=re.IGNORECASE).strip(" ,;")
    text = text.replace(":", ".")
    text = re.sub(r"\bcf\.\s*", "", text, flags=re.IGNORECASE)
    return text


def parse_first_verse_reference(reference: str) -> tuple[str, int, int] | None:
    parsed = re.match(
        r"^\s*((?:[1-3]\s+)?[A-Za-z]+(?:\s+[A-Za-z]+)?)\s+(\d+)[\.:](\d+)",
        reference,
    )
    if parsed is None:
        return None
    return " ".join(parsed.group(1).split()), int(parsed.group(2)), int(parsed.group(3))


def compare_rows(rows: list[dict[str, str]], version: str, db_path: Path) -> list[dict[str, str]]:
    results = []
    for row in rows:
        parsed = parse_first_verse_reference(row["reference"])
        if parsed is None:
            results.append({**row, "status": "unparseable-reference"})
            continue
        book, chapter, verse = parsed
        local = probe.normalized_words(probe.local_verse(db_path, book, chapter, verse))
        external = probe.normalized_words(probe.bolls_verse(version, book, chapter, verse))
        if not local:
            status = "local-missing"
        elif not external:
            status = "bolls-missing"
        elif local == external:
            status = "same-word-sequence"
        elif local in external:
            status = "local-contained-in-bolls"
        elif external in local:
            status = "bolls-contained-in-local"
        else:
            status = "word-sequence-different"
        results.append(
            {
                **row,
                "version": version,
                "book": book,
                "chapter": str(chapter),
                "verse": str(verse),
                "status": status,
                "localWords": local,
                "bollsWords": external,
            }
        )
    return results


def write_csv(rows: list[dict[str, str]], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    fields = sorted(set().union(*(row.keys() for row in rows)))
    with output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def summarize(rows: list[dict[str, str]]) -> dict:
    counts: dict[str, int] = {}
    for row in rows:
        counts[row["status"]] = counts.get(row["status"], 0) + 1
    compatible = sum(
        counts.get(status, 0)
        for status in (
            "same-word-sequence",
            "local-contained-in-bolls",
            "bolls-contained-in-local",
        )
    )
    return {
        "rows": len(rows),
        "statusCounts": counts,
        "compatibleRows": compatible,
        "compatibleRate": compatible / len(rows) if rows else 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-csv",
        type=Path,
        action="append",
        default=[Path("standard_lectionary_complete.csv")],
    )
    parser.add_argument("--sample-size", type=int, default=DEFAULT_SAMPLE_SIZE)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("verification/public-bible-api-probe"),
    )
    args = parser.parse_args()

    references = load_references(args.source_csv)
    rng = random.Random(args.seed)
    sample = rng.sample(references, min(args.sample_size, len(references)))

    comparisons = {
        "RSV2CE": compare_rows(sample, "RSV2CE", Path("assets/rsvce.db")),
        "NABRE": compare_rows(sample, "NABRE", Path("assets/nabre.db")),
    }
    summary = {
        version: summarize(rows)
        for version, rows in comparisons.items()
    }

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for version, rows in comparisons.items():
        write_csv(rows, args.output_dir / f"bolls_{version.lower()}_random_readings.csv")
    (args.output_dir / "bolls_random_readings_summary.json").write_text(
        json.dumps(summary, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
