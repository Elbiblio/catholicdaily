import csv
from contextlib import closing
import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.psalm_sources.models import PsalmEditionText, ReuseStatus, SourceRecord
from scripts.psalm_sources.bible_databases import extract_bible_selection
from scripts.psalm_sources.normalize import (
    normalize_reference,
    parse_responsorial_section,
)
from scripts.psalm_sources.nigeria_365 import (
    extract_rows,
    iter_firestore_documents,
)
from scripts.psalm_sources.local_catalogs import (
    load_local_psalm_rows,
    validate_local_row,
)
from scripts.psalm_sources.modern_psalter import parse_liturgy_page
from scripts.psalm_sources.compare import classify_difference, redact_for_commit
from scripts.psalm_sources.models import PsalmSourceRow


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
            {
                "open",
                "public_domain",
                "licensed",
                "comparison_only",
                "unknown",
            },
        )

    def test_registry_describes_runtime_psalm_editions(self):
        registry = json.loads(
            (ROOT / "scripts/psalm_sources/source_registry.json").read_text(
                encoding="utf-8"
            )
        )
        by_id = {row["source_id"]: row for row in registry}
        for source_id in {
            "nigeria_365_firestore",
            "modern_psalter_us",
            "local_rsvce",
            "local_nabre",
            "douay_rheims",
            "jerusalem_bible",
            "esvce",
        }:
            row = by_id[source_id]
            self.assertIn(row["source_kind"], {"lectionary", "bible", "psalter"})
            self.assertTrue(row["pack_id"])
            self.assertIn(
                row["renderability"], {"bundled", "downloaded", "external"}
            )
            self.assertIn(
                row["coverage_status"], {"complete", "partial", "unavailable"}
            )

    def test_edition_text_row_preserves_complete_text_and_hashes(self):
        row = PsalmEditionText(
            selection_id="ps45_10_11_12_16",
            edition_id="local_rsvce",
            reference_normalized="ps45:10,11,12,16",
            response_text="The queen stands at your right hand, arrayed in gold.",
            stanzas=("A first complete stanza.", "A second complete stanza."),
            source_url="repo://assets/rsvce.db",
        )
        self.assertEqual(
            row.stanzas_text,
            "A first complete stanza.\n\nA second complete stanza.",
        )
        self.assertEqual(len(row.raw_sha256), 64)
        self.assertEqual(len(row.normalized_sha256), 64)


class PsalmNormalizationTest(unittest.TestCase):
    def test_reference_normalization_preserves_verse_parts(self):
        left = normalize_reference("Psalm 45:10.11.12.16 (R.10b)")
        right = normalize_reference("Ps 45:10, 11, 12, 16 (R. 10b)")
        self.assertEqual(left, right)
        self.assertNotEqual(
            left,
            normalize_reference("Ps 45:10, 11, 12, 16 (R. 10)"),
        )


class BibleDatabaseExtractionTest(unittest.TestCase):
    def _build_bible_fixture(self, *, books, verses):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "bible.db"
        with closing(sqlite3.connect(path)) as connection:
            connection.executescript(
                """
                CREATE TABLE books (_id INTEGER PRIMARY KEY, text TEXT, shortname TEXT);
                CREATE TABLE chapters (_id INTEGER, book_id INTEGER);
                CREATE TABLE verses (
                  _id INTEGER PRIMARY KEY,
                  book_id INTEGER,
                  chapter_id INTEGER,
                  verse_id INTEGER,
                  text TEXT
                );
                """
            )
            connection.executemany(
                "INSERT INTO books (_id, text, shortname) VALUES (?, ?, ?)", books
            )
            connection.executemany(
                """INSERT INTO verses
                   (book_id, chapter_id, verse_id, text) VALUES (?, ?, ?, ?)""",
                verses,
            )
            connection.commit()
        return path

    def test_extracts_requested_verses_in_selection_order(self):
        path = self._build_bible_fixture(
            books=[(1, "Psalms", "Ps")],
            verses=[
                (1, 45, 10, "Daughters of kings are among your ladies of honor."),
                (1, 45, 11, "Hear, O daughter, and consider."),
                (1, 45, 12, "The king will desire your beauty."),
                (1, 45, 16, "With joy and gladness they are led along."),
            ],
        )
        result = extract_bible_selection(
            path,
            edition_id="fixture",
            reference="Ps 45:10, 11, 12, 16",
        )
        self.assertEqual(result.reference_normalized, "ps45:10,11,12,16")
        self.assertEqual(len(result.stanzas), 4)
        self.assertIn("Hear, O daughter", result.stanzas_text)

    def test_extracts_canticle_ranges_and_preserves_stanza_groups(self):
        path = self._build_bible_fixture(
            books=[(1, "Isaiah", "Isa")],
            verses=[
                (1, 12, verse, f"Isaiah twelve verse {verse}.")
                for verse in range(2, 7)
            ],
        )
        result = extract_bible_selection(
            path,
            edition_id="fixture",
            reference="Isa 12:2-3, 4, 5-6",
        )
        self.assertEqual(result.reference_normalized, "isa12:2-3,4,5-6")
        self.assertEqual(len(result.stanzas), 3)
        self.assertEqual(
            result.stanzas[0], "Isaiah twelve verse 2. Isaiah twelve verse 3."
        )

    def test_verse_letters_select_the_complete_numbered_verse(self):
        path = self._build_bible_fixture(
            books=[(1, "Psalms", "Ps")],
            verses=[
                (1, 34, verse, f"Complete psalm verse {verse}.")
                for verse in range(2, 10)
            ],
        )
        result = extract_bible_selection(
            path,
            edition_id="fixture",
            reference="Ps 34:2-3a, 4-5, 6-7, 8-9",
        )
        self.assertIn("Complete psalm verse 3.", result.stanzas[0])
        self.assertNotIn("3a", result.stanzas_text)

    def test_bundled_editions_return_complete_distinct_text(self):
        selections = []
        for edition_id, database in (
            ("local_rsvce", ROOT / "assets/rsvce.db"),
            ("local_nabre", ROOT / "assets/nabre.db"),
        ):
            for reference in ("Ps 45:10, 11, 12, 16", "Isa 12:2-3, 4, 5-6"):
                row = extract_bible_selection(
                    database,
                    edition_id=edition_id,
                    reference=reference,
                )
                self.assertTrue(row.stanzas_text)
                self.assertEqual(len(row.raw_sha256), 64)
                selections.append(row)
        self.assertNotEqual(
            selections[0].normalized_sha256,
            selections[2].normalized_sha256,
        )

    def test_parser_extracts_response_and_stanzas(self):
        section = """Psalm 45:10.11.12.16 (R.10b)
R/. On your right stands the queen in gold of Ophir.

The daughters of kings are those whom you favour.
On your right stands the queen in gold of Ophir. R/.

Listen, O daughter; pay heed and give ear;
forget your own people and your father's house. R/.
"""
        parsed = parse_responsorial_section(section)
        self.assertEqual(
            parsed.response,
            "On your right stands the queen in gold of Ophir.",
        )
        self.assertEqual(len(parsed.stanzas), 2)
        self.assertEqual(
            parsed.reference_normalized,
            "ps45:10,11,12,16(r.10b)",
        )

    def test_parser_rejects_non_psalm_field_pollution(self):
        with self.assertRaises(ValueError):
            parse_responsorial_section(
                "ALLELUIA John 14:6 I am the way and the truth"
            )

    def test_parser_accepts_lectionary_canticles_and_noisy_prefixes(self):
        canticle = parse_responsorial_section(
            """Isaiah 12:2-3.4bcde.5-6 (R. see 3)
R/. You will draw water joyfully from the springs of salvation.

God indeed is my saviour;
I am confident and unafraid. R/.
"""
        )
        noisy_psalm = parse_responsorial_section(
            """(Psalm 72:1-2.7-8.12-13.17 (R. 7)
R/. In his days shall justice flourish and great peace for ever.

O God, give your judgement to the king,
to a king's son your justice. R/.
"""
        )
        self.assertEqual(canticle.reference_normalized, "isaiah12:2-3,4bcde,5-6(r.3)")
        self.assertEqual(noisy_psalm.reference_normalized, "ps72:1-2,7-8,12-13,17(r.7)")

    def test_response_line_can_share_a_block_with_the_first_stanza(self):
        parsed = parse_responsorial_section(
            """Psalm 16:1-2a.4.5 and 8.11 (R. 1)
R/. Preserve me, O God, for in you I take refuge.
Preserve me, O God, for in you I take refuge.
I say to the Lord, 'You are my Lord.' R/.

O Lord, it is you who are my portion and cup;
you yourself who secure my lot. R/.
"""
        )
        self.assertEqual(
            parsed.response,
            "Preserve me, O God, for in you I take refuge.",
        )
        self.assertEqual(len(parsed.stanzas), 2)


class Nigeria365ExtractorTest(unittest.TestCase):
    def test_fixture_extracts_january_and_assumption(self):
        fixture = ROOT / "test/fixtures/psalm_sources/nigeria_365_page.json"
        rows = extract_rows(json.loads(fixture.read_text(encoding="utf-8")))
        self.assertEqual(
            [row.date_rule for row in rows],
            ["2026-01-01", "2026-08-15"],
        )
        self.assertEqual(
            rows[1].reference_normalized,
            "ps45:10,11,12,16(r.10b)",
        )
        self.assertIn(
            "queen in gold of ophir",
            rows[1].response_normalized,
        )

    def test_pagination_uses_next_page_token(self):
        pages = iter(
            [
                {"documents": [{"name": "one"}], "nextPageToken": "next"},
                {"documents": [{"name": "two"}]},
            ]
        )
        calls = []
        docs = list(
            iter_firestore_documents(
                lambda token: calls.append(token) or next(pages)
            )
        )
        self.assertEqual(calls, [None, "next"])
        self.assertEqual([doc["name"] for doc in docs], ["one", "two"])

    def test_embedded_alternative_psalms_are_extracted_as_choices(self):
        page = {
            "documents": [
                {
                    "fields": {
                        "mandroiddates": {"stringValue": "04-04-2026"},
                        "title": {"stringValue": "Saturday\nEaster Vigil"},
                        "body": {
                            "stringValue": """RESPONSORIAL PSALM
Psalm 104:1-2a.5-6 (R. cf. 30)
R/. Lord, send forth your Spirit.

Bless the Lord, O my soul! R/.

OR THE FOLLOWING:

RESPONSORIAL PSALM Ps 33:4-5.6-7 (R. 5b)
R/. His merciful love fills the earth.

The word of the Lord is faithful. R/.

SECOND READING Genesis 22:1-18
fixture omitted"""
                        },
                    }
                }
            ]
        }
        rows = extract_rows(page)
        self.assertEqual(len(rows), 2)
        self.assertEqual(
            [row.usage_id for row in rows],
            [
                "ng:2026-04-04:responsorial-psalm:1",
                "ng:2026-04-04:responsorial-psalm:2",
            ],
        )


class LocalPsalmCatalogTest(unittest.TestCase):
    def test_acclamation_in_response_column_is_rejected(self):
        errors = validate_local_row(
            {
                "Full Reference": "Ps 122:1-2, 3-4",
                "Refrain Text RSVCE": "Come, Wisdom of our God Most High",
                "Acclamation Ref": "Luke 3:4, 6",
            }
        )
        self.assertIn("response_contains_acclamation", errors)

    def test_all_three_local_catalogs_are_inventoried(self):
        rows = load_local_psalm_rows(ROOT)
        self.assertTrue(
            {
                "local_standard_lectionary",
                "local_sunday_psalms",
                "local_weekday_psalms",
            }.issubset({row.source_id for row in rows})
        )


class ModernPsalterTest(unittest.TestCase):
    def test_fixture_is_scoped_to_us_philippines(self):
        html = (
            ROOT / "test/fixtures/psalm_sources/modern_psalter_118.html"
        ).read_text(encoding="utf-8")
        row = parse_liturgy_page(
            html,
            "https://www.modernpsalter.com/Lectionary.aspx?n=118",
        )
        self.assertEqual(row["territory"], "US,PH")
        self.assertEqual(row["lectionary_number"], "118")
        self.assertEqual(row["reuse_status"], "comparison_only")


class PsalmComparisonTest(unittest.TestCase):
    def _sample_row(
        self,
        *,
        reuse_status: str,
        stanzas_raw: str,
    ) -> PsalmSourceRow:
        return PsalmSourceRow(
            usage_id="fixture:ps45",
            celebration_id="the_assumption_of_the_blessed_virgin_mary",
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
            response_normalized=(
                "on your right stands the queen in gold of ophir"
            ),
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
        row = self._sample_row(
            reuse_status="comparison_only",
            stanzas_raw="full stanza text",
        )
        redacted = redact_for_commit(row)
        self.assertEqual(redacted.stanzas_raw, "")
        self.assertNotEqual(redacted.normalized_sha256, "")
        self.assertLessEqual(len(redacted.notes), 240)

    def test_open_text_is_retained(self):
        row = self._sample_row(
            reuse_status="open",
            stanzas_raw="full stanza text",
        )
        self.assertEqual(
            redact_for_commit(row).stanzas_raw,
            "full stanza text",
        )


class PsalmCorpusBuildTest(unittest.TestCase):
    def test_fixture_build_is_deterministic_and_safe(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            command = [
                sys.executable,
                "scripts/build_responsorial_psalm_corpus.py",
                "--fixtures-only",
                "--retrieved-at",
                "2026-08-16",
                "--output-dir",
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
        with tempfile.TemporaryDirectory() as output:
            subprocess.run(
                [
                    sys.executable,
                    "scripts/build_responsorial_psalm_corpus.py",
                    "--fixtures-only",
                    "--retrieved-at",
                    "2026-08-16",
                    "--output-dir",
                    output,
                ],
                cwd=ROOT,
                check=True,
            )
            path = Path(output) / "psalm_source_comparison.csv"
            with path.open(encoding="utf-8-sig", newline="") as handle:
                rows = list(csv.DictReader(handle))
            restricted = [
                row
                for row in rows
                if row["reuse_status"] in {"comparison_only", "unknown"}
            ]
            self.assertTrue(restricted)
            self.assertTrue(all(not row["stanzas_raw"] for row in restricted))


if __name__ == "__main__":
    unittest.main()
