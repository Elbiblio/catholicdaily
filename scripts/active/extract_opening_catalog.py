#!/usr/bin/env python3
"""Build an audit-only opening catalog from source-location fixtures.

The output intentionally lives under verification/. It may contain source text
excerpts for audit and matching, and should not be treated as production asset
data unless the relevant source permissions are reviewed separately.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any, Iterable


def build_catalog_entries(fixture_path: Path, repo_root: Path) -> list[dict[str, Any]]:
    fixtures = json.loads(Path(fixture_path).read_text(encoding="utf-8"))
    if not isinstance(fixtures, list):
        raise ValueError(f"Fixture file must contain a list: {fixture_path}")

    entries: list[dict[str, Any]] = []
    for raw in fixtures:
        if not isinstance(raw, dict):
            continue
        text = extract_source_text(repo_root, raw)
        opening100 = text[:100]
        opening200 = text[:200]
        normalized = normalize_fingerprint(opening200)
        entry = {
            "id": raw["id"],
            "key": _catalog_key(raw),
            "date": raw["date"],
            "region": raw["region"],
            "bibleVersion": raw["bibleVersion"],
            "slot": normalize_slot(raw["position"]),
            "position": raw["position"],
            "reference": raw["reference"],
            "sourceLabel": raw.get("sourceLabel", ""),
            "sourcePath": raw["sourcePath"],
            "sourceType": "local_extract",
            "opening100": opening100,
            "opening200": opening200,
            "normalizedFingerprint": normalized,
            "sha256": hashlib.sha256(normalized.encode("utf-8")).hexdigest(),
            "copyrightMode": "audit_only",
        }
        entries.append(entry)
    return entries


def write_catalog(fixture_path: Path, repo_root: Path, output_path: Path) -> None:
    entries = build_catalog_entries(fixture_path, repo_root)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="\n") as handle:
        for entry in entries:
            handle.write(json.dumps(entry, ensure_ascii=False, sort_keys=True))
            handle.write("\n")


def extract_source_text(repo_root: Path, fixture: dict[str, Any]) -> str:
    source_path = repo_root / fixture["sourcePath"]
    if not source_path.exists():
        raise FileNotFoundError(source_path)

    lines = source_path.read_text(encoding="utf-8").replace("\r\n", "\n").replace(
        "\r", "\n"
    ).split("\n")
    start = _find_line(lines, fixture["startMarker"], 0)
    content_start = _find_line(lines, fixture["contentStartMarker"], start)
    end = _find_line(lines, fixture["endMarker"], content_start)

    return "\n".join(
        line for line in lines[content_start:end] if not is_pagination_line(line)
    ).strip()


def normalize_fingerprint(text: str) -> str:
    text = text.replace("\u00a0", " ")
    text = text.replace("“", '"').replace("”", '"')
    text = text.replace("‘", "'").replace("’", "'")
    text = text.replace("—", "-").replace("–", "-")
    words = re.findall(r"[A-Za-z0-9]+(?:'[A-Za-z0-9]+)?", text.lower())
    return " ".join(words)


def normalize_slot(position: str) -> str:
    lower = position.lower()
    if "psalm" in lower:
        return "psalm"
    if "first" in lower:
        return "first"
    if "second" in lower or "epistle" in lower:
        return "second"
    if "gospel" in lower:
        return "gospel"
    return re.sub(r"\s+", "_", lower.strip())


def is_pagination_line(line: str) -> bool:
    trimmed = line.strip()
    if not trimmed:
        return True
    if re.fullmatch(r"=+", trimmed):
        return True
    if re.fullmatch(r"PAGE\s+\d+", trimmed, flags=re.IGNORECASE):
        return True
    if re.fullmatch(r"\d+\s+[A-Z][A-Z\s]+(?:[-\u2013]\s+YEAR\s+[IVX]+)?", trimmed):
        return True
    if re.fullmatch(r"[A-Z]+\s+\d+", trimmed):
        return True
    return trimmed in {"@", "\u00aa", "\u00c2\u00aa", "\u00c3\u201a\u00c2\u00aa"}


def _find_line(lines: list[str], marker: str, start: int) -> int:
    for index in range(start, len(lines)):
        if marker in lines[index]:
            return index
    raise ValueError(f"Marker not found: {marker}")


def _catalog_key(fixture: dict[str, Any]) -> str:
    return "|".join(
        [
            fixture["region"],
            fixture["date"],
            fixture["bibleVersion"],
            normalize_slot(fixture["position"]),
            fixture["reference"],
        ]
    )


def _path_arg(value: str) -> Path:
    return Path(value)


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fixtures",
        type=_path_arg,
        default=Path("verification/exact-reading-fixtures/local_extract_exact_text_samples.json"),
    )
    parser.add_argument("--repo-root", type=_path_arg, default=Path("."))
    parser.add_argument(
        "--output",
        type=_path_arg,
        default=Path("verification/opening-catalog/local-extract-openings.jsonl"),
    )
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    write_catalog(args.fixtures, args.repo_root, args.output)
    entries = build_catalog_entries(args.fixtures, args.repo_root)
    print(f"Wrote {len(entries)} opening catalog entries to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
