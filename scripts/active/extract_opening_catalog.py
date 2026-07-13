#!/usr/bin/env python3
"""Build an audit-only opening catalog from source-location fixtures.

The output intentionally lives under verification/. It may contain source text
excerpts for audit and matching, and should not be treated as production asset
data unless the relevant source permissions are reviewed separately.
"""

from __future__ import annotations

import argparse
import hashlib
import html
from html.parser import HTMLParser
import json
import re
from pathlib import Path
from typing import Any, Iterable
from urllib.request import Request, urlopen


UNIVERSALIS_REGION_PATHS = {
    "GB_EW": "",
    "NG": "africa.nigeria",
}


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


def write_entries(entries: list[dict[str, Any]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="\n") as handle:
        for entry in entries:
            handle.write(json.dumps(entry, ensure_ascii=False, sort_keys=True))
            handle.write("\n")


def write_catalog(fixture_path: Path, repo_root: Path, output_path: Path) -> None:
    write_entries(build_catalog_entries(fixture_path, repo_root), output_path)


def write_universalis_catalog(
    *,
    html_path: Path,
    date: str,
    region: str,
    bible_version: str,
    source_url: str,
    output_path: Path,
) -> None:
    entries = build_universalis_entries_from_html(
        html=html_path.read_text(encoding="utf-8"),
        date=date,
        region=region,
        bible_version=bible_version,
        source_url=source_url,
    )
    write_entries(entries, output_path)


def write_universalis_fetch_catalog(
    *,
    dates: list[str],
    region: str,
    bible_version: str,
    cache_dir: Path,
    output_path: Path,
    fetcher: Any | None = None,
) -> list[dict[str, Any]]:
    fetch = fetcher or fetch_url_text
    cache_dir.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, Any]] = []
    for date in dates:
        source_url = build_universalis_url(date, region)
        html_text = fetch(source_url)
        cache_path = cache_dir / f"universalis-{region.lower()}-{date.replace('-', '')}.html"
        cache_path.write_text(html_text, encoding="utf-8", newline="\n")
        date_entries = build_universalis_entries_from_html(
            html=html_text,
            date=date,
            region=region,
            bible_version=bible_version,
            source_url=source_url,
        )
        if not date_entries:
            raise ValueError(f"No Universalis readings found for {region} {date}")
        entries.extend(date_entries)
    write_entries(entries, output_path)
    return entries


def build_universalis_url(date: str, region: str) -> str:
    date_slug = re.sub(r"[^0-9]", "", date)
    if not re.fullmatch(r"\d{8}", date_slug):
        raise ValueError(f"Universalis date must be YYYY-MM-DD or YYYYMMDD: {date}")
    region_key = region.upper()
    if region_key not in UNIVERSALIS_REGION_PATHS:
        raise ValueError(f"Unsupported Universalis region: {region}")
    region_path = UNIVERSALIS_REGION_PATHS[region_key]
    if region_path:
        return f"https://universalis.com/{region_path}/{date_slug}/mass.htm"
    return f"https://universalis.com/{date_slug}/mass.htm"


def fetch_url_text(url: str) -> str:
    request = Request(url, headers={"User-Agent": "catholicdaily-audit/1.0"})
    with urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def parse_date_args(date: str | None, dates: str | None) -> list[str]:
    values: list[str] = []
    if date:
        values.append(date.strip())
    if dates:
        values.extend(part.strip() for part in dates.split(",") if part.strip())
    if not values:
        raise ValueError("At least one date is required")
    return values


def build_universalis_entries_from_html(
    *,
    html: str,
    date: str,
    region: str,
    bible_version: str,
    source_url: str,
) -> list[dict[str, Any]]:
    sections = _UniversalisMassParser().parse(html)
    entries: list[dict[str, Any]] = []
    for section in sections:
        slot = normalize_slot(section.position)
        if slot == "psalm":
            continue
        text = " ".join(part.strip() for part in section.parts if part.strip()).strip()
        if not text:
            continue
        opening100 = text[:100]
        opening200 = text[:200]
        normalized = normalize_fingerprint(opening200)
        entries.append(
            {
                "id": _entry_id(region, date, bible_version, slot, section.reference),
                "key": "|".join([region, date, bible_version, slot, section.reference]),
                "date": date,
                "region": region,
                "bibleVersion": bible_version,
                "slot": slot,
                "position": section.position,
                "reference": section.reference,
                "sourceLabel": "Universalis Mass readings",
                "sourcePath": "",
                "sourceType": "universalis_web",
                "sourceUrl": source_url,
                "opening100": opening100,
                "opening200": opening200,
                "normalizedFingerprint": normalized,
                "sha256": hashlib.sha256(normalized.encode("utf-8")).hexdigest(),
                "copyrightMode": "audit_only",
            }
        )
    return entries


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
    text = text.replace("\u201c", '"').replace("\u201d", '"')
    text = text.replace("\u2018", "'").replace("\u2019", "'")
    text = text.replace("\u2014", "-").replace("\u2013", "-")
    words = re.findall(r"[A-Za-z0-9]+(?:'[A-Za-z0-9]+)?", text.lower())
    return " ".join(words)


def normalize_slot(position: str) -> str:
    lower = position.lower()
    if "acclamation" in lower:
        return "gospel_acclamation"
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


def _entry_id(region: str, date: str, bible_version: str, slot: str, reference: str) -> str:
    slug = normalize_fingerprint(reference).replace(" ", "-")
    return f"{region.lower()}-{date}-{bible_version.lower()}-{slot}-{slug}"


class _UniversalisSection:
    def __init__(self, position: str, reference: str) -> None:
        self.position = position
        self.reference = reference
        self.parts: list[str] = []


class _UniversalisMassParser(HTMLParser):
    _CONTENT_CLASSES = {"p", "pi", "v", "vi", "gb"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.sections: list[_UniversalisSection] = []
        self._current_section: _UniversalisSection | None = None
        self._in_table = False
        self._in_th = False
        self._th_texts: list[str] = []
        self._current_text: list[str] = []
        self._capture_div = False
        self._div_text: list[str] = []

    def parse(self, html_text: str) -> list[_UniversalisSection]:
        self.feed(html_text)
        self.close()
        return self.sections

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "table" and ("class", "each") in attrs:
            self._in_table = True
            self._th_texts = []
        elif self._in_table and tag == "th":
            self._in_th = True
            self._current_text = []
        elif tag == "div":
            classes = set((dict(attrs).get("class") or "").split())
            if classes & self._CONTENT_CLASSES:
                self._capture_div = True
                self._div_text = []

    def handle_endtag(self, tag: str) -> None:
        if self._in_table and tag == "th":
            self._in_th = False
            text = _clean_html_text(" ".join(self._current_text))
            if text:
                self._th_texts.append(text)
        elif self._in_table and tag == "table":
            self._in_table = False
            self._start_section_from_table()
        elif self._capture_div and tag == "div":
            self._capture_div = False
            text = _clean_html_text(" ".join(self._div_text))
            if self._current_section is not None and text:
                self._current_section.parts.append(text)

    def handle_data(self, data: str) -> None:
        if self._in_th:
            self._current_text.append(data)
        if self._capture_div:
            self._div_text.append(data)

    def _start_section_from_table(self) -> None:
        if len(self._th_texts) < 2:
            return
        position = self._th_texts[0]
        reference = self._th_texts[1]
        slot = normalize_slot(position)
        if slot not in {"first", "second", "psalm", "gospel"}:
            self._current_section = None
            return
        self._current_section = _UniversalisSection(position, reference)
        self.sections.append(self._current_section)


def _clean_html_text(value: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(value).replace("\u00a0", " ")).strip()


def _path_arg(value: str) -> Path:
    return Path(value)


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        choices=["local", "universalis-html", "universalis-fetch"],
        default="local",
        help="Source adapter to run.",
    )
    parser.add_argument(
        "--fixtures",
        type=_path_arg,
        default=Path("verification/exact-reading-fixtures/local_extract_exact_text_samples.json"),
    )
    parser.add_argument("--repo-root", type=_path_arg, default=Path("."))
    parser.add_argument("--html", type=_path_arg)
    parser.add_argument("--date")
    parser.add_argument("--dates", help="Comma-separated extra dates for batch fetches.")
    parser.add_argument("--region")
    parser.add_argument("--bible-version", default="jerusalem")
    parser.add_argument("--source-url", default="")
    parser.add_argument(
        "--cache-dir",
        type=_path_arg,
        default=Path("verification/opening-catalog/source-html"),
    )
    parser.add_argument(
        "--output",
        type=_path_arg,
        default=Path("verification/opening-catalog/local-extract-openings.jsonl"),
    )
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    if args.source == "universalis-html":
        missing = [
            name
            for name in ("html", "date", "region")
            if getattr(args, name.replace("-", "_")) in (None, "")
        ]
        if missing:
            raise SystemExit(
                "--source universalis-html requires --html, --date, and --region"
            )
        entries = build_universalis_entries_from_html(
            html=args.html.read_text(encoding="utf-8"),
            date=args.date,
            region=args.region,
            bible_version=args.bible_version,
            source_url=args.source_url,
        )
        write_entries(entries, args.output)
    elif args.source == "universalis-fetch":
        if not args.region:
            raise SystemExit("--source universalis-fetch requires --region")
        try:
            dates = parse_date_args(args.date, args.dates)
        except ValueError as error:
            raise SystemExit(str(error)) from error
        try:
            entries = write_universalis_fetch_catalog(
                dates=dates,
                region=args.region,
                bible_version=args.bible_version,
                cache_dir=args.cache_dir,
                output_path=args.output,
            )
        except ValueError as error:
            raise SystemExit(str(error)) from error
    else:
        entries = build_catalog_entries(args.fixtures, args.repo_root)
        write_entries(entries, args.output)
    print(f"Wrote {len(entries)} opening catalog entries to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
