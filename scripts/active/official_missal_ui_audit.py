"""Extract selected Nigeria Missal readings from the official Android app UI.

The official app keeps the reading database in private storage, so this uses
UIAutomator against the attached device. It intentionally captures only the
reading metadata we need for regression checks: references, liturgical opening
lines, psalm response, acclamation, and first body line.
"""

from __future__ import annotations

import datetime as dt
import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path


PACKAGE = "ng.com.hybridintegrated.a365dailyreadingsfornigeria"
OUT_DIR = Path("verification/official-ui-audit")
OUT_JSON = Path("verification/official_missal_window_audit.json")

MONTHS = {
    name: i
    for i, name in enumerate(
        [
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December",
        ],
        start=1,
    )
}

SAMPLES = [
    ("key", "2026-05-24", "Pentecost Sunday"),
    ("key", "2026-05-25", "Mary Mother of the Church / weekday check"),
    ("key", "2026-05-26", "Saint Philip Neri"),
    ("key", "2026-05-31", "Most Holy Trinity"),
    ("key", "2026-06-01", "Saint Justin"),
    ("key", "2026-06-03", "Saint Charles Lwanga and Companions"),
    ("key", "2026-06-05", "Saint Boniface"),
    ("key", "2026-06-07", "Corpus Christi"),
    ("key", "2026-06-11", "Saint Barnabas"),
    ("key", "2026-06-12", "Most Sacred Heart of Jesus"),
    ("key", "2026-06-13", "Immaculate Heart / Saint Anthony collision"),
    ("key", "2026-06-24", "Nativity of Saint John the Baptist"),
    ("key", "2026-06-29", "Saints Peter and Paul"),
    ("key", "2026-07-03", "Saint Thomas"),
    ("key", "2026-07-11", "Saint Benedict"),
    ("key", "2026-07-22", "Saint Mary Magdalene"),
    ("random", "2026-05-27", "random weekday"),
    ("random", "2026-05-30", "random weekday"),
    ("random", "2026-06-02", "random weekday"),
    ("random", "2026-06-09", "random weekday"),
    ("random", "2026-06-16", "random weekday"),
    ("random", "2026-06-20", "random weekday"),
    ("random", "2026-06-23", "random weekday"),
    ("random", "2026-06-27", "random weekday"),
    ("random", "2026-07-01", "random weekday"),
    ("random", "2026-07-07", "random weekday"),
    ("random", "2026-07-15", "random weekday"),
]


def load_samples(
    path: str | None,
    dates: str | None = None,
) -> list[tuple[str, str, str]]:
    if dates:
        return [
            ("sample", value.strip(), "ad hoc sample")
            for value in dates.split(",")
            if value.strip()
        ]

    if not path:
        return SAMPLES

    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    samples: list[tuple[str, str, str]] = []
    for item in raw:
        samples.append(
            (
                str(item.get("category", "sample")),
                str(item["date"]),
                str(item.get("note", "")),
            )
        )
    return samples


def run_adb(*args: str, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["adb", *args],
        check=False,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def tap(x: int, y: int) -> None:
    run_adb("shell", "input", "tap", str(x), str(y))


def swipe_up() -> None:
    run_adb("shell", "input", "swipe", "540", "1990", "540", "930", "600")


def center(bounds: str) -> tuple[int, int]:
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
    if not match:
        raise ValueError(f"bad bounds: {bounds}")
    left, top, right, bottom = map(int, match.groups())
    return ((left + right) // 2, (top + bottom) // 2)


def dump_xml(tag: str) -> ET.Element:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    remote = f"/sdcard/{tag}.xml"
    local = OUT_DIR / f"{tag}.xml"
    run_adb("shell", "uiautomator", "dump", "--compressed", remote, timeout=45)
    run_adb("pull", remote, str(local), timeout=20)
    return ET.fromstring(local.read_text(encoding="utf-8", errors="replace"))


def node_texts(root: ET.Element, attr: str) -> list[tuple[str, dict[str, str]]]:
    values: list[tuple[str, dict[str, str]]] = []
    for node in root.iter("node"):
        value = node.attrib.get(attr, "")
        if value:
            values.append((value, node.attrib))
    return values


def all_labels(root: ET.Element) -> list[tuple[str, dict[str, str]]]:
    labels: list[tuple[str, dict[str, str]]] = []
    labels.extend(node_texts(root, "text"))
    labels.extend(node_texts(root, "content-desc"))
    return labels


def repair_text(value: str) -> str:
    if "â" in value or "Â" in value:
        try:
            value = value.encode("latin1").decode("utf-8")
        except UnicodeError:
            pass
    return value.replace("\u00a0", " ").replace("\r\n", "\n")


def longest_reading_text(root: ET.Element) -> str:
    noise = ("Township", "Golden Penny", "INSTALL")
    candidates = []
    for value, _ in node_texts(root, "text"):
        value = repair_text(value)
        if len(value) > 80 and not any(term in value for term in noise):
            candidates.append(value)
    return max(candidates, key=len, default="")


def month_title(root: ET.Element) -> tuple[int, int] | None:
    for value, _ in node_texts(root, "content-desc"):
        match = re.fullmatch(r"([A-Za-z]+) (\d{4})", value.strip())
        if match and match.group(1) in MONTHS:
            return int(match.group(2)), MONTHS[match.group(1)]
    return None


def is_calendar(root: ET.Element) -> bool:
    return month_title(root) is not None and any(
        "Select a date to view daily readings" in value
        for value, _ in node_texts(root, "content-desc")
    )


def open_calendar() -> ET.Element:
    root = dump_xml("current")
    if is_calendar(root):
        return root

    for value, attrs in node_texts(root, "content-desc"):
        if value.strip() == "Calendar" and attrs.get("clickable") == "true":
            x, y = center(attrs["bounds"])
            tap(x, y)
            time.sleep(1.0)
            root = dump_xml("calendar")
            if is_calendar(root):
                return root

    tap(663, 398)
    time.sleep(1.0)
    return dump_xml("calendar_fallback")


def date_label(date: dt.date) -> str:
    return f"{date.strftime('%A')}, {date.strftime('%B')} {date.day}, {date.year}"


def goto_date(date: dt.date) -> None:
    root = open_calendar()
    target_index = date.year * 12 + date.month
    for _ in range(24):
        title = month_title(root)
        if title is None:
            root = open_calendar()
            title = month_title(root)
        if title is None:
            raise RuntimeError("calendar title not found")

        current_index = title[0] * 12 + title[1]
        if current_index < target_index:
            tap(948, 514)
            time.sleep(0.7)
            root = dump_xml("calendar_next")
            continue
        if current_index > target_index:
            tap(132, 514)
            time.sleep(0.7)
            root = dump_xml("calendar_prev")
            continue

        wanted = date_label(date)
        for value, attrs in node_texts(root, "content-desc"):
            if value == wanted:
                x, y = center(attrs["bounds"])
                tap(x, y)
                time.sleep(0.2)
                tap(x, y)
                time.sleep(1.4)
                return
        raise RuntimeError(f"date cell not found: {wanted}")

    raise RuntimeError(f"could not navigate to month for {date.isoformat()}")


def collect_reading_text(date: dt.date) -> tuple[str, str]:
    first_dump = dump_xml(f"{date.isoformat()}_top")
    heading_text = longest_reading_text(first_dump)
    best = heading_text
    for i in range(9):
        root = dump_xml(f"{date.isoformat()}_readings_{i}")
        text = longest_reading_text(root)
        if len(text) > len(best):
            best = text
        if "FIRST READING" in text and "GOSPEL" in text:
            return heading_text, text
        swipe_up()
        time.sleep(0.8)
    return heading_text, best


SECTION_HEADINGS = (
    "FIRST READING",
    "FIRST READNG",
    "FIRSTREADING",
    "SECOND READING",
    "RESPONSORIAL PSALM",
    "ALLELUIA",
    "GOSPEL ACCLAMATION",
    "VERSE BEFORE THE GOSPEL",
    "GOSPEL",
)

HEADING_KEYS = {
    "FIRST READING": "first_reading",
    "FIRST READNG": "first_reading",
    "FIRSTREADING": "first_reading",
    "SECOND READING": "second_reading",
    "RESPONSORIAL PSALM": "psalm",
    "ALLELUIA": "acclamation",
    "GOSPEL ACCLAMATION": "acclamation",
    "VERSE BEFORE THE GOSPEL": "acclamation",
    "GOSPEL": "gospel",
}


def clean_line(value: str) -> str:
    value = value.strip()
    value = value.strip("\"'“”‘’")
    return re.sub(r"\s+", " ", value)


def first_body_line(lines: list[str], start: int) -> str:
    for line in lines[start:]:
        clean = clean_line(line)
        if clean:
            return clean
    return ""


def parse_reading_section(lines: list[str], start: int, next_start: int) -> dict[str, str]:
    section = lines[start:next_start]
    ref = ""
    ref_index = -1
    for i, line in enumerate(section):
        clean = clean_line(line)
        if (
            clean.lower().startswith("a reading from")
            or clean.lower().startswith("the beginning of")
            or clean.lower().startswith("a reading taken from")
        ):
            parenthesized_refs = [
                value
                for value in re.findall(r"\(([^()]*)\)", clean)
                if re.search(r"\d+\s*[:.]\s*\d+", value)
            ]
            if parenthesized_refs:
                ref = clean_line(parenthesized_refs[-1])
            else:
                trailing = re.search(
                    r"((?:[1-3]\s*)?[A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){0,4}\s+\d+[:.]\s*[-\d,.\sandabcf]+)$",
                    clean,
                )
                if trailing:
                    ref = clean_line(trailing.group(1))
            ref_index = i
            break

    if not ref:
        ref_index = -1
        for i, line in enumerate(section):
            clean = clean_line(line)
            parenthesized_refs = [
                value
                for value in re.findall(r"\(([^()]*)\)", clean)
                if re.search(r"\d+\s*[:.]\s*\d+", value)
            ]
            if parenthesized_refs:
                ref = clean_line(parenthesized_refs[-1])
                ref_index = i
                break

    if not ref:
        ref_index = -1
        for i, line in enumerate(section):
            clean = clean_line(line)
            if not (
                clean.lower().startswith("a reading from")
                or clean.lower().startswith("the beginning of")
                or clean.lower().startswith("a reading taken from")
            ):
                continue
            trailing = re.search(
                r"((?:[1-3]\s*)?[A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){0,4}\s+\d+[:.]\s*[-\d,.\sandabcf]+)$",
                clean,
            )
            if trailing:
                ref = clean_line(trailing.group(1))
                ref_index = i
                break
    intro = ""
    if ref_index > 0:
        intro_lines = [clean_line(line) for line in section[1:ref_index] if clean_line(line)]
        intro = " ".join(intro_lines)
    body_start = first_body_line(section, ref_index + 1 if ref_index >= 0 else 1)
    return {"reference": ref, "intro": intro, "body_start": body_start}


def parse_psalm(line: str, lines: list[str], start: int) -> dict[str, str]:
    reference = clean_line(line.replace("RESPONSORIAL PSALM", "", 1))
    response = ""
    for candidate in lines[start + 1 : start + 7]:
        candidate = clean_line(candidate)
        if candidate.startswith("R/."):
            response = candidate
            break
    return {"reference": reference, "response": response}


def parse_acclamation(line: str, lines: list[str], start: int) -> dict[str, str]:
    heading = clean_line(line)
    reference = heading
    for label in ("ALLELUIA", "GOSPEL ACCLAMATION", "VERSE BEFORE THE GOSPEL"):
        if reference.startswith(label):
            reference = clean_line(reference.replace(label, "", 1))
            break
    text = ""
    for candidate in lines[start + 1 : start + 5]:
        candidate = clean_line(candidate)
        if candidate:
            text = candidate
            break
    return {"reference": reference, "text": text}


def parse_sections(text: str) -> dict[str, object]:
    text = repair_text(text)
    lines = [line.strip() for line in text.splitlines()]
    lines = [line for line in lines if line.strip()]
    starts: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        clean = clean_line(line)
        clean_upper = clean.upper()
        for heading in SECTION_HEADINGS:
            if clean_upper == heading or clean_upper.startswith(f"{heading} "):
                starts.append((i, heading))
                break

    starts_with_end = starts + [(len(lines), "END")]
    parsed: dict[str, object] = {}
    for idx, (line_no, heading) in enumerate(starts):
        next_line_no = starts_with_end[idx + 1][0]
        line = clean_line(lines[line_no])
        key = HEADING_KEYS[heading]
        if heading in ("FIRST READING", "FIRSTREADING", "SECOND READING", "GOSPEL"):
            parsed_key = key if key not in parsed else f"alternative_{key}"
            parsed[parsed_key] = parse_reading_section(lines, line_no, next_line_no)
        elif heading == "FIRST READNG":
            parsed_key = key if key not in parsed else f"alternative_{key}"
            parsed[parsed_key] = parse_reading_section(lines, line_no, next_line_no)
        elif heading == "RESPONSORIAL PSALM":
            parsed["psalm"] = parse_psalm(line, lines, line_no)
        else:
            parsed["acclamation"] = parse_acclamation(line, lines, line_no)
    return parsed


def parse_heading(text: str) -> dict[str, str]:
    text = repair_text(text)
    lines = [clean_line(line) for line in text.splitlines() if clean_line(line)]
    return {
        "date_line": lines[0] if lines else "",
        "celebration": lines[1] if len(lines) > 1 else "",
    }


def main(samples: list[tuple[str, str, str]], out_json: Path) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    run_adb("shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(1.0)

    results = []
    for category, iso_date, note in samples:
        date = dt.date.fromisoformat(iso_date)
        print(f"official: {iso_date} {note}", flush=True)
        try:
            goto_date(date)
            heading_text, reading_text = collect_reading_text(date)
            parsed = parse_heading(heading_text)
            parsed.update(parse_sections(reading_text))
            parsed["category"] = category
            parsed["date"] = iso_date
            parsed["note"] = note
            parsed["raw_excerpt"] = repair_text(reading_text)[:3000]
            results.append(parsed)
        except Exception as exc:  # noqa: BLE001 - audit should continue.
            results.append(
                {
                    "category": category,
                    "date": iso_date,
                    "note": note,
                    "error": str(exc),
                }
            )

    out_json.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"wrote {out_json}", flush=True)


def reparse_cache(samples: list[tuple[str, str, str]], out_json: Path) -> None:
    results = []
    for category, iso_date, note in samples:
        date = dt.date.fromisoformat(iso_date)
        top_file = OUT_DIR / f"{date.isoformat()}_top.xml"
        heading_text = ""
        if top_file.exists():
            heading_text = longest_reading_text(ET.fromstring(top_file.read_text(encoding="utf-8")))

        best = ""
        for xml_file in sorted(OUT_DIR.glob(f"{date.isoformat()}_readings_*.xml")):
            text = longest_reading_text(ET.fromstring(xml_file.read_text(encoding="utf-8")))
            if (
                ("FIRST READING" in text or "FIRST READNG" in text)
                and "GOSPEL" in text
            ):
                best = text
                break
            if len(text) > len(best):
                best = text

        parsed = parse_heading(heading_text)
        parsed.update(parse_sections(best))
        parsed["category"] = category
        parsed["date"] = iso_date
        parsed["note"] = note
        parsed["raw_excerpt"] = repair_text(best)[:3000]
        results.append(parsed)

    out_json.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"reparsed {out_json}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample-file", help="JSON list of date sample objects.")
    parser.add_argument(
        "--dates",
        help="Comma-separated ISO dates. Overrides --sample-file when present.",
    )
    parser.add_argument(
        "--out-json",
        default=str(OUT_JSON),
        help="Path to write parsed audit JSON.",
    )
    parser.add_argument(
        "--from-cache",
        action="store_true",
        help="Reparse previously dumped UIAutomator XML instead of driving the app.",
    )
    args = parser.parse_args()

    selected_samples = load_samples(args.sample_file, args.dates)
    output_path = Path(args.out_json)
    if args.from_cache:
        reparse_cache(selected_samples, output_path)
    else:
        main(selected_samples, output_path)
