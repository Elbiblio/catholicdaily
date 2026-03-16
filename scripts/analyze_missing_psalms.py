#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import re
import sqlite3
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path

USER_AGENT = (
    "Mozilla/5.0 (compatible; CatholicDailyPsalmDiagnostics/1.0; "
    "+https://bible.usccb.org)"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="assets/readings.db")
    parser.add_argument("--out", default="scripts/reports/missing_psalm_diagnostics.json")
    parser.add_argument("--max-refs", type=int, default=0, help="0 means all missing refs")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    db_path = Path(args.db).resolve()
    out_path = Path(args.out).resolve()
    print(
        "This legacy missing-psalm diagnostics script is retired. "
        f"Do not inspect {db_path.name} for gaps; build diagnostics from the CSV catalogs instead of {out_path.name}."
    )
    return 1


def build_usccb_url(target_date: dt.date) -> str:
    return f"https://bible.usccb.org/bible/readings/{target_date:%m%d%y}.cfm"


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return ""
        raise


def diagnose_page(page_html: str) -> dict:
    text = html_to_text(page_html)
    lines = [normalize_line(line) for line in text.splitlines()]
    lines = [line for line in lines if line]

    start = index_of(lines, lambda s: "responsorial psalm" in s.lower())
    if start < 0:
        return {"category": "missing_responsorial_psalm_section"}

    stop = len(lines)
    for i in range(start + 1, len(lines)):
        lower = lines[i].lower()
        if (
            "reading ii" in lower
            or re.search(r"\breading\s+2\b", lower)
            or "gospel" in lower
            or "alleluia" in lower
            or "verse before the gospel" in lower
        ):
            stop = i
            break
    block = lines[start:stop]
    if not block:
        return {"category": "empty_psalm_block"}

    has_reference = any(re.match(r"^ps\s+\d+", line, flags=re.IGNORECASE) for line in block)
    refrains = parse_refrains(block)
    if refrains:
        return {
            "category": "parser_should_have_found_refrain",
            "details": {"sample_refrain": refrains[0]},
        }
    if not has_reference:
        return {"category": "psalm_block_without_reference"}
    return {
        "category": "psalm_refrain_pattern_not_matched",
        "details": {"block_head": block[:6]},
    }


def parse_refrains(block: list[str]) -> list[str]:
    patterns = [
        re.compile(r"^R\.\s*\([^)]*\)\s*(.+)$", re.IGNORECASE),
        re.compile(r"^R\.\s*(.+)$", re.IGNORECASE),
        re.compile(r"^R/\s*\([^)]*\)\s*(.+)$", re.IGNORECASE),
        re.compile(r"^R/\s*(.+)$", re.IGNORECASE),
        re.compile(r"^Resp\.\s*(.+)$", re.IGNORECASE),
    ]
    seen = set()
    out = []
    for line in block:
        for pat in patterns:
            m = pat.match(line)
            if not m:
                continue
            v = cleanup_response(m.group(1))
            if v and v not in seen:
                seen.add(v)
                out.append(v)
    return out


def cleanup_response(value: str) -> str:
    value = value.strip()
    value = re.sub(r"\s+", " ", value)
    return value.rstrip(";:,")


def html_to_text(raw_html: str) -> str:
    cleaned = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", raw_html)
    cleaned = re.sub(r"(?i)<br\s*/?>", "\n", cleaned)
    cleaned = re.sub(r"(?i)</(p|div|li|h1|h2|h3|h4|h5|h6|tr|section)>", "\n", cleaned)
    cleaned = re.sub(r"(?is)<[^>]+>", " ", cleaned)
    return html.unescape(cleaned)


def normalize_line(line: str) -> str:
    return re.sub(r"\s+", " ", line.replace("\xa0", " ")).strip()


def index_of(items: list[str], pred) -> int:
    for i, item in enumerate(items):
        if pred(item):
            return i
    return -1


if __name__ == "__main__":
    raise SystemExit(main())

