# Responsorial Psalm Source Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic, source-neutral comparison corpus for Nigerian and international responsorial-psalm sources and generate a reviewed runtime-text candidate asset.

**Architecture:** Python adapters ingest cached or live source material into one `PsalmSourceRow` model. A shared canonicalizer separates responses, stanza blocks, and scripture selections; a comparison stage emits stable long-form CSVs and a JSON audit report. Full text is committed only for rows marked open, public-domain, or licensed; comparison-only sources retain fingerprints and short diagnostics.

**Tech Stack:** Python 3 standard library, Firestore REST JSON, HTML parsing, CSV/JSON, SHA-256, pytest-compatible `unittest`, existing Flutter repository verification conventions.

---

## File Map

- Create `scripts/psalm_sources/__init__.py`: package marker for extractor imports.
- Create `scripts/psalm_sources/models.py`: typed row and source-registry models.
- Create `scripts/psalm_sources/normalize.py`: reference, response, stanza, and text canonicalization.
- Create `scripts/psalm_sources/nigeria_365.py`: Firestore and fixture ingestion.
- Create `scripts/psalm_sources/local_catalogs.py`: existing CSV and Bible-source ingestion.
- Create `scripts/psalm_sources/modern_psalter.py`: territory/index metadata ingestion.
- Create `scripts/psalm_sources/compare.py`: matching, scoring, classification, and output filtering.
- Create `scripts/psalm_sources/source_registry.json`: investigated-source inventory and reuse decisions.
- Create `scripts/build_responsorial_psalm_corpus.py`: deterministic command-line orchestration.
- Create `test/scripts/responsorial_psalm_corpus_test.py`: extractor and output contract tests.
- Create `test/fixtures/psalm_sources/nigeria_365_page.json`: sanitized January 1 and Assumption samples.
- Create `test/fixtures/psalm_sources/modern_psalter_118.html`: minimal cached comparator page.
- Create `verification/psalm_sources/psalm_source_inventory.csv`: generated source inventory.
- Create `verification/psalm_sources/psalm_source_comparison.csv`: generated long-form comparison.
- Create `verification/psalm_sources/responsorial_psalm_audit_report.json`: generated findings.
- Create `assets/data/responsorial_psalm_texts.csv`: reviewed display-eligible candidate rows.

### Task 1: Lock the source registry and row contract

**Files:**
- Create: `scripts/psalm_sources/models.py`
- Create: `scripts/psalm_sources/__init__.py`
- Create: `scripts/psalm_sources/source_registry.json`
- Test: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Write the failing model and registry tests**

```python
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.psalm_sources.models import ReuseStatus, SourceRecord


class PsalmSourceRegistryTest(unittest.TestCase):
    def test_registry_has_required_candidate_sources(self):
        raw = json.loads(
            (ROOT / "scripts/psalm_sources/source_registry.json").read_text(
                encoding="utf-8"
            )
        )
        records = [SourceRecord.from_dict(item) for item in raw]
        ids = {record.source_id for record in records}
        self.assertTrue(
            {
                "nigeria_365_firestore",
                "modern_psalter_us",
                "local_standard_lectionary",
                "local_sunday_psalms",
                "local_weekday_psalms",
                "local_rsvce",
                "local_nabre",
                "revised_grail_evidence",
                "abbey_psalms_evidence",
                "newman_jerusalem_bible",
                "universalis_nigeria",
            }.issubset(ids)
        )

    def test_reuse_status_is_closed_enum(self):
        self.assertEqual(
            {status.value for status in ReuseStatus},
            {"open", "public_domain", "licensed", "comparison_only", "unknown"},
        )
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```powershell
python test/scripts/responsorial_psalm_corpus_test.py -v
```

Expected: FAIL because `scripts.psalm_sources.models` and the registry do not exist.

- [ ] **Step 3: Implement the typed contracts**

Create an empty `scripts/psalm_sources/__init__.py`, then add the following model implementation.

```python
from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import Enum
from typing import Any


class ReuseStatus(str, Enum):
    OPEN = "open"
    PUBLIC_DOMAIN = "public_domain"
    LICENSED = "licensed"
    COMPARISON_ONLY = "comparison_only"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class SourceRecord:
    source_id: str
    source_name: str
    source_edition: str
    source_territory: str
    source_url: str
    source_license: str
    reuse_status: ReuseStatus
    coverage: str
    access_method: str
    notes: str

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "SourceRecord":
        return cls(
            source_id=str(raw["source_id"]),
            source_name=str(raw["source_name"]),
            source_edition=str(raw.get("source_edition", "")),
            source_territory=str(raw.get("source_territory", "")),
            source_url=str(raw["source_url"]),
            source_license=str(raw.get("source_license", "unknown")),
            reuse_status=ReuseStatus(str(raw["reuse_status"])),
            coverage=str(raw.get("coverage", "")),
            access_method=str(raw.get("access_method", "")),
            notes=str(raw.get("notes", "")),
        )


@dataclass(frozen=True)
class PsalmSourceRow:
    usage_id: str
    celebration_id: str
    celebration_title: str
    date_rule: str
    season: str
    week: str
    weekday: str
    sunday_cycle: str
    weekday_cycle: str
    lectionary_number: str
    territory: str
    reading_set_kind: str
    reading_set_priority: int
    biblical_book: str
    psalm_number_hebrew: str
    psalm_number_vulgate: str
    reference_raw: str
    reference_normalized: str
    stanza_selection_normalized: str
    response_verse_normalized: str
    source_id: str
    source_name: str
    source_edition: str
    source_territory: str
    source_url: str
    retrieved_at: str
    source_license: str
    reuse_status: str
    response_raw: str
    response_normalized: str
    stanzas_raw: str
    stanzas_normalized: str
    raw_sha256: str
    normalized_sha256: str
    token_count: int
    comparison_target: str = ""
    reference_match_score: str = ""
    response_match_score: str = ""
    stanza_match_score: str = ""
    text_match_score: str = ""
    difference_class: str = ""
    review_status: str = "unreviewed"
    notes: str = ""
    display_eligible: bool = False
    display_priority: int = 0
    eligibility_basis: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
```

Create `source_registry.json` with these explicit initial records. The audit may append newly discovered sources, but it must not weaken a listed reuse status without recorded evidence.

```json
[
  {"source_id":"nigeria_365_firestore","source_name":"Catholic Missal for Nigeria / 365 Readings","source_edition":"live Nigerian daily corpus","source_territory":"NG","source_url":"https://firestore.googleapis.com/v1/projects/catholic-missal/databases/(default)/documents/NigeriaReading","source_license":"No redistribution grant found in publisher terms","reuse_status":"comparison_only","coverage":"2025-2026 daily records at audit time","access_method":"public Firestore REST","notes":"Comparator for Nigerian Ordo assignments and displayed wording"},
  {"source_id":"modern_psalter_us","source_name":"Modern Psalter Lectionary Index","source_edition":"United States/Philippines","source_territory":"US,PH","source_url":"https://www.modernpsalter.com/Lectionary.aspx?n=118","source_license":"ICEL responses; site copyright notice","reuse_status":"comparison_only","coverage":"Sundays, principal feasts, and ritual selections","access_method":"public HTML","notes":"Territory-specific comparator, not a Nigerian authority"},
  {"source_id":"local_standard_lectionary","source_name":"Catholic Daily standard lectionary catalog","source_edition":"repository snapshot","source_territory":"WORLD","source_url":"repo://standard_lectionary_complete.csv","source_license":"repository internal data","reuse_status":"licensed","coverage":"standard assignments","access_method":"local CSV","notes":"Assignments and generic responses"},
  {"source_id":"local_sunday_psalms","source_name":"Catholic Daily Sunday psalm supplement","source_edition":"repository snapshot","source_territory":"WORLD","source_url":"repo://lectionary_psalms.csv","source_license":"repository internal data","reuse_status":"licensed","coverage":"Sundays and principal celebrations","access_method":"local CSV","notes":"Contains known field-alignment defects requiring validation"},
  {"source_id":"local_weekday_psalms","source_name":"Catholic Daily weekday psalm supplement","source_edition":"repository snapshot","source_territory":"WORLD","source_url":"repo://lectionary_psalms_weekday.csv","source_license":"repository internal data","reuse_status":"licensed","coverage":"weekday cycles","access_method":"local CSV","notes":"Contains known field-alignment defects requiring validation"},
  {"source_id":"local_rsvce","source_name":"Catholic Daily RSVCE database","source_edition":"repository Bible asset","source_territory":"WORLD","source_url":"repo://assets/rsvce.db","source_license":"Existing app Bible license; verify before exporting text","reuse_status":"comparison_only","coverage":"complete Bible psalm verses","access_method":"SQLite","notes":"Bible fallback, not exact lectionary stanza authority"},
  {"source_id":"local_nabre","source_name":"Catholic Daily NABRE database","source_edition":"repository Bible asset","source_territory":"US","source_url":"repo://assets/nabre.db","source_license":"Existing app Bible license; verify before exporting text","reuse_status":"comparison_only","coverage":"complete Bible psalm verses","access_method":"SQLite","notes":"Bible fallback, not Nigerian lectionary authority"},
  {"source_id":"revised_grail_evidence","source_name":"Michel Guimont Lectionary Psalms sample","source_edition":"Revised Grail Psalms 2010","source_territory":"evidence","source_url":"https://s3.amazonaws.com/cdn.giamusic.com/pdf/GuimontLectionaryPsalms.pdf","source_license":"Copyright Conception Abbey and The Grail; administered by GIA","reuse_status":"comparison_only","coverage":"published sample settings","access_method":"public PDF","notes":"Edition-identification evidence"},
  {"source_id":"abbey_psalms_evidence","source_name":"USCCB Liturgy of the Hours Second Edition history","source_edition":"Abbey Psalms and Canticles","source_territory":"US","source_url":"https://www.usccb.org/prayer-and-worship/liturgy-of-the-hours/liturgy-of-the-hours-second-edition","source_license":"USCCB copyright information","reuse_status":"comparison_only","coverage":"edition history and status","access_method":"public HTML","notes":"Edition/provenance evidence, not a full-text corpus"},
  {"source_id":"newman_jerusalem_bible","source_name":"Notre Dame Newman Centre liturgy planning","source_edition":"Jerusalem Bible lectionary text","source_territory":"GB/IE comparator","source_url":"https://newman.nd.edu/liturgy-planning/sunday-liturgies/","source_license":"Jerusalem Bible text used by permission","reuse_status":"comparison_only","coverage":"Sundays and principal celebrations","access_method":"public HTML","notes":"Translation comparator"},
  {"source_id":"universalis_nigeria","source_name":"Universalis Nigeria Mass readings","source_edition":"Universalis online translation","source_territory":"NG","source_url":"https://universalis.com/nigeria/mass.htm","source_license":"Universalis copyright; online translation","reuse_status":"comparison_only","coverage":"current regional Mass readings","access_method":"public HTML","notes":"Regional assignment comparator; wording is not assumed to be the Nigerian print lectionary"}
]
```

- [ ] **Step 4: Run the tests and verify GREEN**

Run the Task 1 command again.

Expected: two tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/psalm_sources/__init__.py scripts/psalm_sources/models.py scripts/psalm_sources/source_registry.json test/scripts/responsorial_psalm_corpus_test.py
git commit -m "test: define psalm source corpus contract"
```

### Task 2: Parse and canonicalize responsorial psalms

**Files:**
- Create: `scripts/psalm_sources/normalize.py`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Add failing canonicalization tests**

```python
from scripts.psalm_sources.normalize import (
    normalize_reference,
    parse_responsorial_section,
)


class PsalmNormalizationTest(unittest.TestCase):
    def test_reference_normalization_preserves_verse_parts(self):
        left = normalize_reference("Psalm 45:10.11.12.16 (R.10b)")
        right = normalize_reference("Ps 45:10, 11, 12, 16 (R. 10b)")
        self.assertEqual(left, right)
        self.assertNotEqual(left, normalize_reference("Ps 45:10, 11, 12, 16 (R. 10)"))

    def test_parser_extracts_response_and_stanzas(self):
        section = """Psalm 45:10.11.12.16 (R.10b)
R/. On your right stands the queen in gold of Ophir.

The daughters of kings are those whom you favour.
On your right stands the queen in gold of Ophir. R/.

Listen, O daughter; pay heed and give ear;
forget your own people and your father's house. R/.
"""
        parsed = parse_responsorial_section(section)
        self.assertEqual(parsed.response, "On your right stands the queen in gold of Ophir.")
        self.assertEqual(len(parsed.stanzas), 2)
        self.assertEqual(parsed.reference_normalized, "ps45:10,11,12,16(r.10b)")

    def test_parser_rejects_non_psalm_field_pollution(self):
        with self.assertRaises(ValueError):
            parse_responsorial_section("ALLELUIA John 14:6 I am the way and the truth")
```

- [ ] **Step 2: Run and verify RED**

Run:

```powershell
python test/scripts/responsorial_psalm_corpus_test.py -v
```

Expected: FAIL because the normalization module does not exist.

- [ ] **Step 3: Implement canonicalization**

```python
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import re
import unicodedata


@dataclass(frozen=True)
class ParsedPsalm:
    reference_raw: str
    reference_normalized: str
    response: str
    response_normalized: str
    stanzas: tuple[str, ...]
    stanzas_normalized: str
    raw_sha256: str
    normalized_sha256: str


def _clean_unicode(value: str) -> str:
    return unicodedata.normalize("NFC", value).replace("\u00a0", " ")


def normalize_words(value: str) -> str:
    value = _clean_unicode(value).lower()
    value = re.sub(r"\b(?:r/\.?|r\.)\b", " ", value, flags=re.IGNORECASE)
    value = re.sub(r"[^\w']+", " ", value, flags=re.UNICODE)
    return " ".join(value.split())


def normalize_reference(value: str) -> str:
    value = _clean_unicode(value).lower().strip()
    value = re.sub(r"^(?:psalm|ps)\s*", "ps", value)
    value = re.sub(r"\b(?:cf\.?|see)\s*", "", value)
    value = value.replace(" and ", ",")
    value = re.sub(r"[.;]+(?=\d)", ",", value)
    value = re.sub(r"\s+", "", value)
    value = re.sub(r",+", ",", value)
    return value


def _strip_response_marker(value: str) -> str:
    value = re.sub(r"^\s*R\s*/?\.?\s*", "", value, flags=re.IGNORECASE)
    return re.sub(r"\s+R\s*/?\.?\s*$", "", value, flags=re.IGNORECASE).strip()


def parse_responsorial_section(section: str) -> ParsedPsalm:
    raw = _clean_unicode(section).strip()
    if re.match(r"^(?:ALLELUIA|GOSPEL|SECOND READING)\b", raw, re.IGNORECASE):
        raise ValueError("not a responsorial psalm section")
    blocks = [block.strip() for block in re.split(r"\n\s*\n", raw) if block.strip()]
    if len(blocks) < 2:
        raise ValueError("responsorial psalm has no text blocks")
    header_lines = blocks[0].splitlines()
    reference_raw = header_lines[0].strip()
    response = ""
    body_blocks: list[str] = []
    remainder = "\n".join(header_lines[1:]).strip()
    if remainder:
        if re.match(r"^R\s*/?\.", remainder, re.IGNORECASE):
            response = _strip_response_marker(remainder)
        else:
            body_blocks.append(remainder)
    for block in blocks[1:]:
        cleaned = _strip_response_marker(block)
        if not response and re.match(r"^R\s*/?\.", block, re.IGNORECASE):
            response = cleaned
        elif response and normalize_words(cleaned) == normalize_words(response):
            continue
        else:
            body_blocks.append(cleaned)
    if not response or not body_blocks:
        raise ValueError("responsorial psalm is missing response or stanzas")
    stanzas = tuple("\n".join(line.rstrip() for line in b.splitlines()) for b in body_blocks)
    normalized = "\n\n".join(normalize_words(item) for item in stanzas)
    whole = response + "\n\n" + "\n\n".join(stanzas)
    normalized_whole = normalize_words(response) + "\n\n" + normalized
    return ParsedPsalm(
        reference_raw=reference_raw,
        reference_normalized=normalize_reference(reference_raw),
        response=response,
        response_normalized=normalize_words(response),
        stanzas=stanzas,
        stanzas_normalized=normalized,
        raw_sha256=hashlib.sha256(whole.encode("utf-8")).hexdigest(),
        normalized_sha256=hashlib.sha256(normalized_whole.encode("utf-8")).hexdigest(),
    )
```

- [ ] **Step 4: Run normalization tests**

Expected: three tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/psalm_sources/normalize.py test/scripts/responsorial_psalm_corpus_test.py
git commit -m "feat: normalize lectionary psalm selections"
```

### Task 3: Extract the Nigerian app comparator reproducibly

**Files:**
- Create: `scripts/psalm_sources/nigeria_365.py`
- Create: `test/fixtures/psalm_sources/nigeria_365_page.json`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Save a sanitized two-document fixture**

The fixture must retain the Firestore envelope and only the `name`, `mandroiddates`, `title`, and `body` fields for 2026-01-01 and 2026-08-15. Keep each full responsorial-psalm section but replace unrelated reading text with `fixture omitted` so tests never become a bulk mirror of the app.

- [ ] **Step 2: Add failing fixture and pagination tests**

```python
from scripts.psalm_sources.nigeria_365 import extract_rows, iter_firestore_documents


class Nigeria365ExtractorTest(unittest.TestCase):
    def test_fixture_extracts_january_and_assumption(self):
        fixture = ROOT / "test/fixtures/psalm_sources/nigeria_365_page.json"
        rows = extract_rows(json.loads(fixture.read_text(encoding="utf-8")))
        self.assertEqual([row.date_rule for row in rows], ["2026-01-01", "2026-08-15"])
        self.assertEqual(rows[1].reference_normalized, "ps45:10,11,12,16(r.10b)")
        self.assertIn("queen in gold of ophir", rows[1].response_normalized)

    def test_pagination_uses_next_page_token(self):
        pages = iter([
            {"documents": [{"name": "one"}], "nextPageToken": "next"},
            {"documents": [{"name": "two"}]},
        ])
        calls = []
        docs = list(iter_firestore_documents(lambda token: calls.append(token) or next(pages)))
        self.assertEqual(calls, [None, "next"])
        self.assertEqual([doc["name"] for doc in docs], ["one", "two"])
```

- [ ] **Step 3: Run and verify RED**

Expected: FAIL because the adapter does not exist.

- [ ] **Step 4: Implement fixture and live Firestore ingestion**

```python
from __future__ import annotations

from collections.abc import Callable, Iterator
from dataclasses import replace
from datetime import date
import json
from urllib.parse import quote
from urllib.request import urlopen

from .models import PsalmSourceRow, ReuseStatus, SourceRecord
from .normalize import parse_responsorial_section


FIRESTORE_URL = (
    "https://firestore.googleapis.com/v1/projects/catholic-missal/"
    "databases/(default)/documents/NigeriaReading?pageSize=100"
)


def iter_firestore_documents(fetch_page: Callable[[str | None], dict]) -> Iterator[dict]:
    token: str | None = None
    while True:
        page = fetch_page(token)
        yield from page.get("documents", [])
        token = page.get("nextPageToken")
        if not token:
            return


def fetch_live_page(token: str | None) -> dict:
    url = FIRESTORE_URL if token is None else FIRESTORE_URL + "&pageToken=" + quote(token)
    with urlopen(url, timeout=60) as response:
        return json.load(response)


def _field(doc: dict, name: str) -> str:
    return str(doc.get("fields", {}).get(name, {}).get("stringValue", ""))


def _psalm_section(body: str) -> str | None:
    import re
    match = re.search(
        r"RESPONSORIAL\s+PSALM\s*:?[ \t]*(.*?)(?=\n\s*(?:SECOND\s+READING|ALLELUIA|GOSPEL\s+ACCLAMATION|GOSPEL)\b)",
        body,
        flags=re.IGNORECASE | re.DOTALL,
    )
    return match.group(1).strip() if match else None


def extract_rows(page: dict, source: SourceRecord | None = None) -> list[PsalmSourceRow]:
    if source is None:
        source = SourceRecord(
            source_id="nigeria_365_firestore",
            source_name="Catholic Missal for Nigeria / 365 Readings",
            source_edition="live Nigerian daily corpus",
            source_territory="NG",
            source_url=FIRESTORE_URL,
            source_license="comparison audit only",
            reuse_status=ReuseStatus.COMPARISON_ONLY,
            coverage="daily Nigerian records",
            access_method="public Firestore REST",
            notes="",
        )
    rows: list[PsalmSourceRow] = []
    for doc in page.get("documents", []):
        section = _psalm_section(_field(doc, "body"))
        if not section:
            continue
        parsed = parse_responsorial_section(section)
        raw_date = _field(doc, "mandroiddates")
        day, month, year = raw_date.split("-")
        iso_date = f"{year}-{month}-{day}"
        rows.append(
            PsalmSourceRow(
                usage_id=f"ng:{iso_date}:responsorial-psalm:1",
                celebration_id="",
                celebration_title=_field(doc, "title").splitlines()[1] if "\n" in _field(doc, "title") else "",
                date_rule=iso_date,
                season="", week="", weekday="", sunday_cycle="", weekday_cycle="",
                lectionary_number="", territory="NG", reading_set_kind="resolved-day",
                reading_set_priority=1, biblical_book="Ps",
                psalm_number_hebrew="", psalm_number_vulgate="",
                reference_raw=parsed.reference_raw,
                reference_normalized=parsed.reference_normalized,
                stanza_selection_normalized=parsed.reference_normalized,
                response_verse_normalized="",
                source_id=source.source_id, source_name=source.source_name,
                source_edition=source.source_edition, source_territory=source.source_territory,
                source_url=source.source_url, retrieved_at=date.today().isoformat(),
                source_license=source.source_license, reuse_status=source.reuse_status.value,
                response_raw=parsed.response, response_normalized=parsed.response_normalized,
                stanzas_raw="\n\n".join(parsed.stanzas),
                stanzas_normalized=parsed.stanzas_normalized,
                raw_sha256=parsed.raw_sha256, normalized_sha256=parsed.normalized_sha256,
                token_count=len((parsed.response_normalized + " " + parsed.stanzas_normalized).split()),
                comparison_target="nigeria_365_firestore",
            )
        )
    return rows
```

- [ ] **Step 5: Run the extractor tests**

Expected: fixture and pagination tests PASS without network access.

- [ ] **Step 6: Commit**

```powershell
git add scripts/psalm_sources/nigeria_365.py test/fixtures/psalm_sources/nigeria_365_page.json test/scripts/responsorial_psalm_corpus_test.py
git commit -m "feat: extract Nigerian responsorial psalm comparator"
```

### Task 4: Ingest local catalogs and Modern Psalter metadata

**Files:**
- Create: `scripts/psalm_sources/local_catalogs.py`
- Create: `scripts/psalm_sources/modern_psalter.py`
- Create: `test/fixtures/psalm_sources/modern_psalter_118.html`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Add failing local corruption tests**

```python
from scripts.psalm_sources.local_catalogs import load_local_psalm_rows, validate_local_row


class LocalPsalmCatalogTest(unittest.TestCase):
    def test_acclamation_in_response_column_is_rejected(self):
        errors = validate_local_row({
            "Full Reference": "Ps 122:1-2, 3-4",
            "Refrain Text RSVCE": "Come, Wisdom of our God Most High",
            "Acclamation Ref": "Luke 3:4, 6",
        })
        self.assertIn("response_contains_acclamation", errors)

    def test_all_three_local_catalogs_are_inventoried(self):
        rows = load_local_psalm_rows(ROOT)
        self.assertTrue({
            "local_standard_lectionary",
            "local_sunday_psalms",
            "local_weekday_psalms",
        }.issubset({row.source_id for row in rows}))
```

- [ ] **Step 2: Add a failing Modern Psalter territory test**

```python
from scripts.psalm_sources.modern_psalter import parse_liturgy_page


class ModernPsalterTest(unittest.TestCase):
    def test_fixture_is_scoped_to_us_philippines(self):
        html = (ROOT / "test/fixtures/psalm_sources/modern_psalter_118.html").read_text(encoding="utf-8")
        row = parse_liturgy_page(html, "https://www.modernpsalter.com/Lectionary.aspx?n=118")
        self.assertEqual(row["territory"], "US,PH")
        self.assertEqual(row["lectionary_number"], "118")
        self.assertEqual(row["reuse_status"], "comparison_only")
```

- [ ] **Step 3: Run and verify RED**

Expected: FAIL because both adapters are missing.

- [ ] **Step 4: Implement local CSV ingestion**

Use `csv.DictReader(..., encoding="utf-8-sig")`, map each source file to its registry ID, and emit one `PsalmSourceRow` for each row with a parseable psalm reference. Preserve every original column in the audit notes when a semantic validation error occurs. `validate_local_row` must flag response text beginning with `Alleluia`, `Come,`, or a non-psalm scripture citation when that field is supposed to contain the response.

```python
def validate_local_row(raw: dict[str, str]) -> list[str]:
    response = (raw.get("Refrain Text RSVCE") or raw.get("Refrain Text") or "").strip()
    errors: list[str] = []
    if response.lower().startswith(("alleluia", "come, wisdom", "come, leader", "come, king")):
        errors.append("response_contains_acclamation")
    if response and re.match(r"^(?:John|Luke|Matthew|Mark|Isaiah)\s+\d", response, re.IGNORECASE):
        errors.append("response_contains_scripture_reference")
    return errors
```

- [ ] **Step 5: Implement Modern Psalter metadata ingestion**

The adapter records lectionary number, title, territory selector, ICEL notice, and URL. It does not infer Nigerian equivalence or production eligibility. Parse the cached fixture in tests and allow live HTML only behind the build command's `--refresh-live` flag.

- [ ] **Step 6: Run Task 4 tests**

Expected: all local and Modern Psalter tests PASS.

- [ ] **Step 7: Commit**

```powershell
git add scripts/psalm_sources/local_catalogs.py scripts/psalm_sources/modern_psalter.py test/fixtures/psalm_sources/modern_psalter_118.html test/scripts/responsorial_psalm_corpus_test.py
git commit -m "feat: ingest psalm comparison sources"
```

### Task 5: Compare variants and enforce text eligibility

**Files:**
- Create: `scripts/psalm_sources/compare.py`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`

- [ ] **Step 1: Add failing comparison tests**

```python
from dataclasses import replace
from scripts.psalm_sources.compare import classify_difference, redact_for_commit


class PsalmComparisonTest(unittest.TestCase):
    def _sample_row(self, *, reuse_status: str, stanzas_raw: str) -> PsalmSourceRow:
        return PsalmSourceRow(
            usage_id="fixture:ps45",
            celebration_id="assumption_of_blessed_virgin_mary",
            celebration_title="The Assumption of the Blessed Virgin Mary",
            date_rule="08-15",
            season="",
            week="",
            weekday="",
            sunday_cycle="A/B/C",
            weekday_cycle="I/II",
            lectionary_number="",
            territory="NG",
            reading_set_kind="celebration",
            reading_set_priority=1,
            biblical_book="Ps",
            psalm_number_hebrew="45",
            psalm_number_vulgate="44",
            reference_raw="Ps 45:10, 11, 12, 16",
            reference_normalized="ps45:10,11,12,16",
            stanza_selection_normalized="10,11,12,16",
            response_verse_normalized="10b",
            source_id="fixture_source",
            source_name="Fixture Source",
            source_edition="Fixture Edition",
            source_territory="NG",
            source_url="https://www.modernpsalter.com/Lectionary.aspx?n=622",
            retrieved_at="2026-08-16",
            source_license="fixture",
            reuse_status=reuse_status,
            response_raw="On your right stands the queen in gold of Ophir.",
            response_normalized="on your right stands the queen in gold of ophir",
            stanzas_raw=stanzas_raw,
            stanzas_normalized="full stanza text",
            raw_sha256="a" * 64,
            normalized_sha256="b" * 64,
            token_count=3,
        )

    def test_punctuation_only_is_not_translation_variant(self):
        self.assertEqual(
            classify_difference("Lord, hear us.", "Lord hear us"),
            "punctuation_only",
        )

    def test_comparison_only_text_is_redacted(self):
        row = self._sample_row(reuse_status="comparison_only", stanzas_raw="full stanza text")
        redacted = redact_for_commit(row)
        self.assertEqual(redacted.stanzas_raw, "")
        self.assertNotEqual(redacted.normalized_sha256, "")
        self.assertLessEqual(len(redacted.notes), 240)

    def test_open_text_is_retained(self):
        row = self._sample_row(reuse_status="open", stanzas_raw="full stanza text")
        self.assertEqual(redact_for_commit(row).stanzas_raw, "full stanza text")
```

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because `compare.py` is missing.

- [ ] **Step 3: Implement classification, scoring, and redaction**

```python
from dataclasses import replace
from difflib import SequenceMatcher
import re

from .models import PsalmSourceRow
from .normalize import normalize_words


def similarity(left: str, right: str) -> float:
    return round(SequenceMatcher(None, normalize_words(left), normalize_words(right)).ratio(), 6)


def classify_difference(left: str, right: str) -> str:
    if left == right:
        return "exact"
    if normalize_words(left) == normalize_words(right):
        return "punctuation_only"
    if left.casefold() == right.casefold():
        return "orthography_only"
    return "translation_variant"


def redact_for_commit(row: PsalmSourceRow) -> PsalmSourceRow:
    if row.reuse_status in {"open", "public_domain", "licensed"}:
        return row
    diagnostic = " ".join((row.response_normalized + " " + row.stanzas_normalized).split()[:12])
    return replace(
        row,
        response_raw="",
        stanzas_raw="",
        stanzas_normalized="",
        notes=(row.notes + f" diagnostic={diagnostic}").strip()[:240],
    )
```

Extend `classify_difference` in the completed file to emit every class required by the design: `response_only`, `stanza_boundary_only`, `selection_mismatch`, `missing_text`, and `parse_error`. Use explicit conditions before the translation-variant fallback.

- [ ] **Step 4: Run comparison tests**

Expected: all comparison and eligibility tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/psalm_sources/compare.py test/scripts/responsorial_psalm_corpus_test.py
git commit -m "feat: compare and classify psalm text variants"
```

### Task 6: Generate deterministic CSVs, runtime candidates, and audit report

**Files:**
- Create: `scripts/build_responsorial_psalm_corpus.py`
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`
- Create: `verification/psalm_sources/psalm_source_inventory.csv`
- Create: `verification/psalm_sources/psalm_source_comparison.csv`
- Create: `verification/psalm_sources/responsorial_psalm_audit_report.json`
- Create: `assets/data/responsorial_psalm_texts.csv`

- [ ] **Step 1: Add failing deterministic-output tests**

```python
import csv
import subprocess
import tempfile


class PsalmCorpusBuildTest(unittest.TestCase):
    def test_fixture_build_is_deterministic_and_safe(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            command = [
                "python", "scripts/build_responsorial_psalm_corpus.py",
                "--fixtures-only", "--output-dir",
            ]
            subprocess.run(command + [first], cwd=ROOT, check=True)
            subprocess.run(command + [second], cwd=ROOT, check=True)
            for name in (
                "psalm_source_inventory.csv",
                "psalm_source_comparison.csv",
                "responsorial_psalm_audit_report.json",
                "responsorial_psalm_texts.csv",
            ):
                self.assertEqual(
                    (Path(first) / name).read_bytes(),
                    (Path(second) / name).read_bytes(),
                )

    def test_comparison_only_rows_have_no_committed_full_text(self):
        path = ROOT / "verification/psalm_sources/psalm_source_comparison.csv"
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        restricted = [row for row in rows if row["reuse_status"] in {"comparison_only", "unknown"}]
        self.assertTrue(restricted)
        self.assertTrue(all(not row["stanzas_raw"] for row in restricted))
```

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because the build command and outputs do not exist.

- [ ] **Step 3: Implement the build command**

The CLI accepts:

```text
--fixtures-only
--refresh-live
--output-dir PATH
--retrieved-at YYYY-MM-DD
```

Default to fixtures/cached inputs and `2026-08-16` from the registry snapshot, not `date.today()`, so committed regeneration is deterministic. `--refresh-live` stages network data in a temporary directory and updates the retrieval date only after validation.

The build command must:

1. load and validate the registry;
2. collect local rows;
3. collect fixture or live Nigerian rows;
4. collect Modern Psalter metadata;
5. canonicalize and group compatible usages;
6. score against the Nigerian target and other requested targets;
7. redact non-redistributable text;
8. write inventory and comparison CSVs with `PsalmSourceRow` field order;
9. write only reviewed `display_eligible=true` rows to the runtime asset;
10. write exact counts and conflicts to the JSON report;
11. fail before replacing outputs if any schema, parse, provenance, or eligibility check fails.

The runtime asset must use this exact 15-column header, matching the Dart loader in the runtime plan:

```csv
usage_id,territory,celebration_id,date_rule,sunday_cycle,weekday_cycle,lectionary_number,reading_set_kind,reference_normalized,response_text,stanzas_text,source_id,source_edition,source_url,display_priority
```

`reference_normalized` in this runtime-only CSV excludes `(R. ...)` notation because `response_text` carries the reviewed response separately. `stanzas_text` contains literal `\n` and `\n\n` escape sequences, never physical line breaks, so every asset row occupies one CSV line and can be parsed by `ReadingCatalogService.parseCsvLine`.

- [ ] **Step 4: Generate the committed artifacts**

Run:

```powershell
python scripts/build_responsorial_psalm_corpus.py --fixtures-only --output-dir verification/psalm_sources --retrieved-at 2026-08-16
Copy-Item verification/psalm_sources/responsorial_psalm_texts.csv assets/data/responsorial_psalm_texts.csv
```

Expected: four stable artifacts, no raw comparison-only corpus, no APK, no secret.

- [ ] **Step 5: Run all extractor tests**

```powershell
python test/scripts/responsorial_psalm_corpus_test.py -v
python scripts/build_responsorial_psalm_corpus.py --fixtures-only --output-dir "$env:TEMP\responsorial-psalm-rebuild" --retrieved-at 2026-08-16
git diff --check
```

Expected: tests PASS; the fixture rebuild succeeds; diff check is clean.

- [ ] **Step 6: Review the audit counts**

Confirm the report includes non-zero candidate-source count, Nigerian usage count, normalized unique count, conflicts, parse failures, display-eligible count, and unmatched count. Confirm no error count is silently omitted.

- [ ] **Step 7: Commit**

```powershell
git add scripts/build_responsorial_psalm_corpus.py test/scripts/responsorial_psalm_corpus_test.py verification/psalm_sources assets/data/responsorial_psalm_texts.csv
git commit -m "data: build responsorial psalm comparison corpus"
```

### Task 7: Refresh the live Nigerian snapshot without committing raw text

**Files:**
- Modify: `verification/psalm_sources/psalm_source_inventory.csv`
- Modify: `verification/psalm_sources/psalm_source_comparison.csv`
- Modify: `verification/psalm_sources/responsorial_psalm_audit_report.json`
- Modify: `assets/data/responsorial_psalm_texts.csv` only if reviewed eligibility permits it

- [ ] **Step 1: Run live refresh to staging**

```powershell
$stage = Join-Path $env:TEMP 'responsorial-psalm-live-refresh'
python scripts/build_responsorial_psalm_corpus.py --refresh-live --output-dir $stage --retrieved-at 2026-08-16
```

Expected: all public Firestore pages download; no API key is required or written.

- [ ] **Step 2: Compare live and fixture reports**

```powershell
git diff --no-index -- verification/psalm_sources/responsorial_psalm_audit_report.json "$stage\responsorial_psalm_audit_report.json"
```

Expected: live counts reflect the full collection; known fixture rows retain identical normalized hashes.

- [ ] **Step 3: Promote only safe generated outputs**

Copy the inventory, redacted comparison CSV, and report from staging. Promote runtime rows only after their source edition and eligibility basis are reviewed. Do not copy raw cached Firestore JSON.

- [ ] **Step 4: Re-run all tests and inspect for secrets**

```powershell
python test/scripts/responsorial_psalm_corpus_test.py -v
rg -n "AIza|firebase_api_key|config\.armeabi|\.apk$" verification/psalm_sources assets/data/responsorial_psalm_texts.csv
git diff --check
```

Expected: tests PASS; secret/artifact search has no matches; diff check clean.

- [ ] **Step 5: Commit**

```powershell
git add verification/psalm_sources assets/data/responsorial_psalm_texts.csv
git commit -m "data: audit Nigerian responsorial psalm corpus"
```
