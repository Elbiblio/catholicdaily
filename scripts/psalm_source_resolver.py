#!/usr/bin/env python3
"""
Tiered psalm response resolver with multiple fallback sources.

Resolution order:
1. USCCB (primary, official source)
2. Cached per-year/cycle (existing database)
3. CatholicGallery (fallback scraper)
4. Unresolved (report for manual review)
"""
from __future__ import annotations

import datetime as dt
import html
import json
import re
import sqlite3
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Protocol

USER_AGENT = (
    "Mozilla/5.0 (compatible; CatholicDailyPsalmResolver/1.0; "
    "+https://bible.usccb.org)"
)


@dataclass(frozen=True)
class PsalmResponse:
    """Resolved psalm response with metadata."""
    response: str
    alternatives: list[str]
    source: str  # "usccb", "cache", "catholicgallery", etc.
    source_url: str
    confidence: float  # 0.0-1.0


class PsalmSource(Protocol):
    """Protocol for psalm response sources."""
    
    def fetch_response(
        self,
        date: dt.date,
        psalm_ref: str,
        year: int,
        sunday_cycle: str,
        weekday_cycle: str,
    ) -> PsalmResponse | None:
        """Fetch psalm response for given date and context."""
        ...


class USCCBSource:
    """Primary source: USCCB official daily readings."""
    
    def __init__(self, retry_count: int = 3, retry_delay: float = 2.0):
        self.retry_count = retry_count
        self.retry_delay = retry_delay
    
    def fetch_response(
        self,
        date: dt.date,
        psalm_ref: str,
        year: int,
        sunday_cycle: str,
        weekday_cycle: str,
    ) -> PsalmResponse | None:
        url = f"https://bible.usccb.org/bible/readings/{date:%m%d%y}.cfm"
        
        for attempt in range(self.retry_count):
            try:
                page = self._fetch(url)
                if not page:
                    return None
                
                response, alternatives = self._extract_refrain(page)
                if response:
                    return PsalmResponse(
                        response=response,
                        alternatives=alternatives,
                        source="usccb",
                        source_url=url,
                        confidence=1.0,
                    )
                return None
            except urllib.error.HTTPError as exc:
                if exc.code == 404:
                    return None
                if attempt < self.retry_count - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                    continue
                raise
            except Exception:
                if attempt < self.retry_count - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                    continue
                raise
        
        return None
    
    def _fetch(self, url: str) -> str:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=25) as resp:
            return resp.read().decode("utf-8", errors="replace")
    
    def _extract_refrain(self, page_html: str) -> tuple[str | None, list[str]]:
        if not page_html.strip():
            return None, []
        
        text = self._html_to_text(page_html)
        lines = [self._normalize_line(line) for line in text.splitlines()]
        lines = [line for line in lines if line]
        
        start = self._index_of(lines, lambda s: "responsorial psalm" in s.lower())
        if start < 0:
            return None, []
        
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
        refrains = self._parse_refrains(block)
        return (refrains[0] if refrains else None, refrains)
    
    def _parse_refrains(self, block: list[str]) -> list[str]:
        patterns = [
            re.compile(r"^R\.\s*\([^)]*\)\s*(.+)$", re.IGNORECASE),
            re.compile(r"^R\.\s*(.+)$", re.IGNORECASE),
            re.compile(r"^R/\s*\([^)]*\)\s*(.+)$", re.IGNORECASE),
            re.compile(r"^R/\s*(.+)$", re.IGNORECASE),
            re.compile(r"^Resp\.\s*(.+)$", re.IGNORECASE),
        ]
        seen: set[str] = set()
        out: list[str] = []
        for line in block:
            for pat in patterns:
                m = pat.match(line)
                if not m:
                    continue
                text = self._cleanup_response(m.group(1))
                if text and text not in seen:
                    seen.add(text)
                    out.append(text)
        return out
    
    def _cleanup_response(self, value: str) -> str:
        value = re.sub(r"\s+", " ", value).strip()
        return value.rstrip(";:,")
    
    def _html_to_text(self, raw_html: str) -> str:
        cleaned = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", raw_html)
        cleaned = re.sub(r"(?i)<br\s*/?>", "\n", cleaned)
        cleaned = re.sub(r"(?i)</(p|div|li|h1|h2|h3|h4|h5|h6|tr|section)>", "\n", cleaned)
        cleaned = re.sub(r"(?is)<[^>]+>", " ", cleaned)
        return html.unescape(cleaned)
    
    def _normalize_line(self, line: str) -> str:
        return re.sub(r"\s+", " ", line.replace("\xa0", " ")).strip()
    
    def _index_of(self, items: list[str], pred) -> int:
        for i, item in enumerate(items):
            if pred(item):
                return i
        return -1


class CachedSource:
    """Secondary source: existing database cache by year/cycle."""
    
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
    
    def fetch_response(
        self,
        date: dt.date,
        psalm_ref: str,
        year: int,
        sunday_cycle: str,
        weekday_cycle: str,
    ) -> PsalmResponse | None:
        # Look for existing responses in same year/cycle with same psalm ref
        start = int(dt.datetime(year, 1, 1, tzinfo=dt.UTC).timestamp())
        end = int(dt.datetime(year + 1, 1, 1, tzinfo=dt.UTC).timestamp())
        
        row = self.conn.execute(
            """
            SELECT psalm_response, psalm_response_alternatives, psalm_response_cache_key
            FROM readings
            WHERE position = 2
              AND timestamp >= ?
              AND timestamp < ?
              AND reading = ?
              AND psalm_response IS NOT NULL
              AND TRIM(psalm_response) <> ''
            LIMIT 1
            """,
            (start, end, psalm_ref),
        ).fetchone()
        
        if not row:
            return None
        
        response = str(row["psalm_response"]).strip()
        alternatives = []
        if row["psalm_response_alternatives"]:
            try:
                alternatives = json.loads(row["psalm_response_alternatives"])
            except Exception:
                pass
        
        cache_key = row["psalm_response_cache_key"] or f"cache://{year}/{sunday_cycle}/{weekday_cycle}"
        
        return PsalmResponse(
            response=response,
            alternatives=alternatives,
            source="cache",
            source_url=cache_key,
            confidence=0.9,
        )


class CatholicGallerySource:
    """Tertiary source: CatholicGallery.org scraper."""
    
    def __init__(self, retry_count: int = 2, retry_delay: float = 1.5):
        self.retry_count = retry_count
        self.retry_delay = retry_delay
    
    def fetch_response(
        self,
        date: dt.date,
        psalm_ref: str,
        year: int,
        sunday_cycle: str,
        weekday_cycle: str,
    ) -> PsalmResponse | None:
        # CatholicGallery URL format: /mass-reading/DDMMYY/
        url = f"https://www.catholicgallery.org/mass-reading/{date:%d%m%y}/"
        
        for attempt in range(self.retry_count):
            try:
                page = self._fetch(url)
                if not page:
                    return None
                
                response, alternatives = self._extract_refrain(page)
                if response:
                    return PsalmResponse(
                        response=response,
                        alternatives=alternatives,
                        source="catholicgallery",
                        source_url=url,
                        confidence=0.7,  # Lower confidence - secondary source
                    )
                return None
            except urllib.error.HTTPError as exc:
                if exc.code == 404:
                    return None
                if attempt < self.retry_count - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                    continue
                return None
            except Exception:
                if attempt < self.retry_count - 1:
                    time.sleep(self.retry_delay * (attempt + 1))
                    continue
                return None
        
        return None
    
    def _fetch(self, url: str) -> str:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.read().decode("utf-8", errors="replace")
    
    def _extract_refrain(self, page_html: str) -> tuple[str | None, list[str]]:
        if not page_html.strip():
            return None, []
        
        text = self._html_to_text(page_html)
        lines = [self._normalize_line(line) for line in text.splitlines()]
        lines = [line for line in lines if line]
        
        # Look for "Responsorial Psalm" or "Psalm" section
        start = -1
        for i, line in enumerate(lines):
            lower = line.lower()
            if "responsorial psalm" in lower or (
                "psalm" in lower and i > 0 and "reading" in lines[i - 1].lower()
            ):
                start = i
                break
        
        if start < 0:
            return None, []
        
        # Find end of psalm section
        stop = len(lines)
        for i in range(start + 1, len(lines)):
            lower = lines[i].lower()
            if (
                "second reading" in lower
                or "reading ii" in lower
                or "gospel acclamation" in lower
                or "alleluia" in lower
                or "gospel" in lower
            ):
                stop = i
                break
        
        block = lines[start:stop]
        refrains = self._parse_refrains(block)
        return (refrains[0] if refrains else None, refrains)
    
    def _parse_refrains(self, block: list[str]) -> list[str]:
        # CatholicGallery uses "R. (...) text" format
        patterns = [
            re.compile(r"^R\.\s*\([^)]*\)\s*(.+)$", re.IGNORECASE),
            re.compile(r"^R\.\s*(.+)$", re.IGNORECASE),
            re.compile(r"^Response:\s*(.+)$", re.IGNORECASE),
            re.compile(r"^Resp\.\s*(.+)$", re.IGNORECASE),
        ]
        seen: set[str] = set()
        out: list[str] = []
        for line in block:
            for pat in patterns:
                m = pat.match(line)
                if not m:
                    continue
                text = self._cleanup_response(m.group(1))
                if text and text not in seen:
                    seen.add(text)
                    out.append(text)
        return out
    
    def _cleanup_response(self, value: str) -> str:
        value = re.sub(r"\s+", " ", value).strip()
        return value.rstrip(";:,")
    
    def _html_to_text(self, raw_html: str) -> str:
        cleaned = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", raw_html)
        cleaned = re.sub(r"(?i)<br\s*/?>", "\n", cleaned)
        cleaned = re.sub(r"(?i)</(p|div|li|h1|h2|h3|h4|h5|h6|tr|section)>", "\n", cleaned)
        cleaned = re.sub(r"(?is)<[^>]+>", " ", cleaned)
        return html.unescape(cleaned)
    
    def _normalize_line(self, line: str) -> str:
        return re.sub(r"\s+", " ", line.replace("\xa0", " ")).strip()


class TieredPsalmResolver:
    """Tiered psalm response resolver with multiple fallback sources."""
    
    def __init__(self, conn: sqlite3.Connection):
        self.sources: list[PsalmSource] = [
            USCCBSource(retry_count=3, retry_delay=2.0),
            CachedSource(conn),
            CatholicGallerySource(retry_count=2, retry_delay=1.5),
        ]
    
    def resolve(
        self,
        date: dt.date,
        psalm_ref: str,
        year: int,
        sunday_cycle: str,
        weekday_cycle: str,
    ) -> PsalmResponse | None:
        """
        Attempt to resolve psalm response using tiered sources.
        
        Returns first successful response or None if all sources fail.
        """
        for source in self.sources:
            try:
                result = source.fetch_response(
                    date, psalm_ref, year, sunday_cycle, weekday_cycle
                )
                if result:
                    return result
            except Exception as exc:
                # Log but continue to next source
                print(f"  [{source.__class__.__name__}] Error: {exc}")
                continue
        
        return None
    
    def resolve_with_report(
        self,
        date: dt.date,
        psalm_ref: str,
        year: int,
        sunday_cycle: str,
        weekday_cycle: str,
    ) -> tuple[PsalmResponse | None, dict[str, str]]:
        """
        Resolve with detailed report of each source attempt.
        
        Returns (result, report_dict) where report_dict contains
        status for each source: "success", "not_found", "error: <msg>"
        """
        report: dict[str, str] = {}
        
        for source in self.sources:
            source_name = source.__class__.__name__.replace("Source", "").lower()
            try:
                result = source.fetch_response(
                    date, psalm_ref, year, sunday_cycle, weekday_cycle
                )
                if result:
                    report[source_name] = "success"
                    return result, report
                report[source_name] = "not_found"
            except Exception as exc:
                report[source_name] = f"error: {exc}"
                continue
        
        return None, report


def liturgical_year_for_date(date: dt.date) -> int:
    """Calculate liturgical year for a given date."""
    advent = calculate_advent_start(date.year)
    return date.year + 1 if date >= advent else date.year


def sunday_cycle_for_date(date: dt.date) -> str:
    """Calculate Sunday lectionary cycle (A, B, C) for a given date."""
    year = liturgical_year_for_date(date)
    cycles = ["A", "B", "C"]
    return cycles[(year + 1) % 3]


def weekday_cycle_for_date(date: dt.date) -> str:
    """Calculate weekday lectionary cycle (I, II) for a given date."""
    year = liturgical_year_for_date(date)
    return "II" if year % 2 == 0 else "I"


def calculate_advent_start(year: int) -> dt.date:
    """Calculate first Sunday of Advent for a given year."""
    christmas = dt.date(year, 12, 25)
    days_to_prev_sunday = (christmas.weekday() + 1) % 7
    return christmas - dt.timedelta(days=days_to_prev_sunday + 21)
