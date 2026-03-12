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
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    # Missing refs and their seed dates.
    rows = conn.execute(
        """
        SELECT reading, MIN(timestamp) AS seed_ts, COUNT(*) AS missing_count
        FROM readings
        WHERE position = 2
          AND (psalm_response IS NULL OR TRIM(psalm_response) = '')
        GROUP BY reading
        ORDER BY missing_count DESC
        """
    ).fetchall()
    if args.max_refs > 0:
        rows = rows[: args.max_refs]

    # Refs that already have a known response somewhere in DB.
    known_rows = conn.execute(
        """
        SELECT reading, COUNT(DISTINCT psalm_response) AS c, MIN(psalm_response) AS v
        FROM readings
        WHERE position = 2
          AND psalm_response IS NOT NULL
          AND TRIM(psalm_response) <> ''
        GROUP BY reading
        """
    ).fetchall()
    known_map = {
        str(r["reading"]): str(r["v"]).strip()
        for r in known_rows
        if int(r["c"]) == 1 and str(r["v"]).strip()
    }

    diagnostics: list[dict] = []
    category_counter: Counter[str] = Counter()

    for row in rows:
        ref = str(row["reading"])
        seed_ts = int(row["seed_ts"])
        missing_count = int(row["missing_count"])
        seed_date = dt.datetime.fromtimestamp(seed_ts, tz=dt.UTC).date()

        if ref in known_map:
            category = "can_fill_from_existing_reference_mapping"
            diagnostics.append(
                {
                    "reference": ref,
                    "missing_count": missing_count,
                    "seed_date": seed_date.isoformat(),
                    "category": category,
                    "known_response": known_map[ref],
                }
            )
            category_counter[category] += 1
            continue

        url = build_usccb_url(seed_date)
        page = fetch(url)
        if not page:
            category = "source_not_found_404_or_empty"
            diagnostics.append(
                {
                    "reference": ref,
                    "missing_count": missing_count,
                    "seed_date": seed_date.isoformat(),
                    "category": category,
                    "source_url": url,
                }
            )
            category_counter[category] += 1
            continue

        parse = diagnose_page(page)
        category = parse["category"]
        diagnostics.append(
            {
                "reference": ref,
                "missing_count": missing_count,
                "seed_date": seed_date.isoformat(),
                "category": category,
                "source_url": url,
                "details": parse.get("details"),
            }
        )
        category_counter[category] += 1

    conn.close()

    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "total_missing_refs_analyzed": len(diagnostics),
        "category_counts": dict(category_counter),
        "diagnostics": diagnostics,
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=True, indent=2), encoding="utf-8")
    print(f"Wrote diagnostics: {out_path}")
    print("Category counts:", dict(category_counter))
    return 0


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

