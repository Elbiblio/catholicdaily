from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from html.parser import HTMLParser
import re

from .normalize import normalize_reference, normalize_words
from .bible_databases import parse_selection


_MONTHS = {
    name.lower(): number
    for number, name in enumerate(
        (
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
        ),
        start=1,
    )
}


@dataclass(frozen=True)
class HistoricalPsalmEvidence:
    date_rule: str
    reference_raw: str
    reference_normalized: str
    response_raw: str
    response_normalized: str
    stanzas_raw: str
    stanzas_normalized: str
    source_id: str
    source_edition: str
    source_url: str


def selection_reference(value: str) -> str:
    """Remove response-verse notation while retaining the stanza selection."""

    value = value.replace("&", ",")
    value = re.sub(
        r"(?:[.,]?r\.?)?\([^)]*\)$",
        "",
        value.strip(),
        flags=re.I,
    )
    return value.rstrip(".)")


def selection_signature(value: str) -> tuple[tuple[str, int, tuple[int, ...]], ...]:
    """Compare the numbered verses independent of stanza part notation."""

    parsed = parse_selection(selection_reference(value))
    verses_by_chapter: dict[int, set[int]] = {}
    for group in parsed.groups:
        verses_by_chapter.setdefault(group.chapter, set()).update(group.verses)
    return tuple(
        (parsed.book, chapter, tuple(sorted(verses)))
        for chapter, verses in verses_by_chapter.items()
    )


class _VisibleTextParser(HTMLParser):
    _BLOCKS = {
        "article",
        "br",
        "div",
        "h1",
        "h2",
        "h3",
        "h4",
        "li",
        "p",
        "section",
    }

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.ignored_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"script", "style"}:
            self.ignored_depth += 1
        elif not self.ignored_depth and tag in self._BLOCKS:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style"} and self.ignored_depth:
            self.ignored_depth -= 1
        elif not self.ignored_depth and tag in self._BLOCKS:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if not self.ignored_depth:
            self.parts.append(data)


def visible_lines(html: str) -> list[str]:
    parser = _VisibleTextParser()
    parser.feed(html)
    text = "".join(parser.parts).replace("\u00a0", " ")
    return [re.sub(r"\s+", " ", line).strip() for line in text.splitlines() if line.strip()]


def _date_from_lines(lines: list[str]) -> str:
    patterns = (
        r"\b(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)\s*,?\s*(2024|2025)\b",
        r"\b([A-Za-z]+)\s+(\d{1,2}),\s*(2024|2025)\b",
    )
    for line in lines:
        for index, pattern in enumerate(patterns):
            match = re.search(pattern, line, flags=re.IGNORECASE)
            if match is None:
                continue
            if index == 0:
                day_number, month_name, year = match.groups()
            else:
                month_name, day_number, year = match.groups()
            month = _MONTHS.get(month_name.lower())
            if month is not None:
                return date(int(year), month, int(day_number)).isoformat()
    raise ValueError("historical source has no supported 2024/2025 date")


def _date_from_gallery_url(source_url: str) -> str:
    match = re.search(r"/mass-reading/(\d{2})(\d{2})(\d{2})/?", source_url)
    if match is None:
        raise ValueError("Catholic Gallery URL has no DDMMYY date")
    day_number, month, year = (int(value) for value in match.groups())
    return date(2000 + year, month, day_number).isoformat()


def _clean_reference(value: str) -> str:
    value = re.sub(
        r"^Responsorial Psalm\s*:\s*",
        "",
        value,
        flags=re.IGNORECASE,
    )
    return value.strip()


def _clean_response(value: str) -> str:
    value = re.sub(r"^R\s*/?\.\s*", "", value, flags=re.IGNORECASE)
    value = re.sub(r"^\([^)]*\)\s*", "", value)
    return value.strip()


def parse_catholic_leaf_psalm(
    html: str,
    *,
    source_url: str,
) -> HistoricalPsalmEvidence:
    lines = visible_lines(html)
    source_date = _date_from_lines(lines)
    reference = ""
    response = ""
    for index, line in enumerate(lines):
        if not re.match(r"^(?:Responsorial\s+)?Psalm\s+\d", line, re.IGNORECASE):
            continue
        reference = _clean_reference(line)
        for candidate in lines[index + 1 : index + 7]:
            if re.match(r"^R\s*/?\.", candidate, re.IGNORECASE):
                response = _clean_response(candidate)
                break
        if response:
            break
    if not reference or not response:
        raise ValueError("Catholic Leaf post has no responsorial selection")
    return HistoricalPsalmEvidence(
        date_rule=source_date,
        reference_raw=reference,
        reference_normalized=normalize_reference(reference),
        response_raw=response,
        response_normalized=normalize_words(response),
        stanzas_raw="",
        stanzas_normalized="",
        source_id="catholic_leaf_archive",
        source_edition="dated Catholic lectionary response archive",
        source_url=source_url,
    )


def parse_catholic_gallery_psalm(
    html: str,
    *,
    source_url: str,
) -> HistoricalPsalmEvidence:
    lines = visible_lines(html)
    source_date = _date_from_gallery_url(source_url)
    candidates = [
        index
        for index, line in enumerate(lines)
        if line.lower().startswith("responsorial psalm")
    ]
    for start in reversed(candidates):
        line = lines[start]
        reference = _clean_reference(line)
        cursor = start + 1
        if not reference and cursor < len(lines):
            reference = lines[cursor]
            cursor += 1
        response_index = next(
            (
                index
                for index in range(cursor, min(len(lines), cursor + 12))
                if re.match(r"^R\s*/?\.", lines[index], re.IGNORECASE)
            ),
            None,
        )
        if response_index is None:
            continue
        response = _clean_response(lines[response_index])
        stanza_lines: list[str] = []
        for candidate in lines[response_index + 1 :]:
            if re.match(
                r"^(?:Second Reading|Alleluia|Gospel(?: Acclamation)?|First Reading)\b",
                candidate,
                flags=re.IGNORECASE,
            ):
                break
            if re.match(r"^R\s*/?\.", candidate, re.IGNORECASE):
                continue
            if candidate and not candidate.startswith("(adsbygoogle"):
                stanza_lines.append(candidate)
        stanzas = "\n".join(stanza_lines).strip()
        if not reference or not response or not stanzas:
            continue
        return HistoricalPsalmEvidence(
            date_rule=source_date,
            reference_raw=reference,
            reference_normalized=normalize_reference(reference),
            response_raw=response,
            response_normalized=normalize_words(response),
            stanzas_raw=stanzas,
            stanzas_normalized=normalize_words(stanzas),
            source_id="catholic_gallery_douay_archive",
            source_edition="Douay-Rheims dated Mass-reading archive",
            source_url=source_url,
        )
    raise ValueError("Catholic Gallery page has no complete responsorial selection")


def parse_universalis_calendar(html: str, *, year: int) -> dict[str, str]:
    calendar: dict[str, str] = {}
    month = 0
    for row in re.findall(r"<tr\b[^>]*>(.*?)</tr>", html, flags=re.I | re.S):
        header = re.search(r"<th\b[^>]*>(.*?)</th>", row, flags=re.I | re.S)
        if header is not None:
            labels = visible_lines(header.group(1))
            if labels and labels[0].lower() in _MONTHS:
                month = _MONTHS[labels[0].lower()]
            continue
        cells = re.findall(r"<td\b[^>]*>(.*?)</td>", row, flags=re.I | re.S)
        if month == 0 or len(cells) < 2:
            continue
        day_label = " ".join(visible_lines(cells[0]))
        day_match = re.search(r"(\d{1,2})\s*$", day_label)
        titles = visible_lines(cells[1])
        if day_match is None or not titles:
            continue
        source_date = date(year, month, int(day_match.group(1))).isoformat()
        calendar[source_date] = " ".join(titles)
    return calendar
