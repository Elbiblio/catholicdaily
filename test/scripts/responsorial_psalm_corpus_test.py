import csv
from contextlib import closing
from dataclasses import replace
from datetime import date, timedelta
import json
import re
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import URLError
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.psalm_sources.models import PsalmEditionText, ReuseStatus, SourceRecord
from scripts.psalm_sources.bible_databases import (
    extract_bible_selection,
    parse_selection,
)
from scripts.psalm_sources.edition_corpus import (
    build_wide_comparison,
    write_csv_rows,
)
from scripts.psalm_sources.source_packs import (
    RuntimePsalmPackRow,
    build_manifest,
    pack_rows_from_editions,
    pack_rows_from_source_rows,
    validate_source_pack,
    write_runtime_packs,
)
from scripts.psalm_sources.normalize import (
    normalize_reference,
    normalize_words,
    parse_responsorial_section,
)
from scripts.psalm_sources.nigeria_365 import (
    canonicalize_nigeria_reference,
    extract_rows,
    fetch_live_page,
    iter_firestore_documents,
)
from scripts.psalm_sources.nigeria_usage_catalog import (
    NigeriaPsalmUsageAssignment,
    build_nigeria_usage_catalog,
    validate_nigeria_usage_catalog,
)
from scripts.psalm_sources.nigeria_assignment_rules import (
    infer_nigeria_assignments,
    temporal_context,
)
from scripts.psalm_sources.liturgical_usage_universe import (
    build_liturgical_usage_universe,
    normalize_selection_reference,
    validate_liturgical_usage_universe,
)
from scripts.build_complete_nigeria_psalm_coverage import load_nigeria_pack
from scripts.psalm_sources.nigeria_text_reconstruction import (
    build_verified_fragment_index,
    reconstruct_nigeria_selection,
)
from scripts.psalm_sources.local_catalogs import (
    load_local_psalm_rows,
    validate_local_row,
)
from scripts.psalm_sources.modern_psalter import parse_liturgy_page
from scripts.psalm_sources.compare import classify_difference, redact_for_commit
from scripts.psalm_sources.models import PsalmSourceRow, PsalmUsage


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

    def test_nigeria_source_uses_exact_public_name(self):
        registry = json.loads(
            (ROOT / "scripts/psalm_sources/source_registry.json").read_text(
                encoding="utf-8"
            )
        )
        nigeria = next(
            row
            for row in registry
            if row["source_id"] == "nigeria_365_firestore"
        )
        self.assertEqual(
            nigeria["source_name"],
            "Catholic Missal for Nigeria",
        )
        self.assertNotIn("365 Readings", json.dumps(nigeria))

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
        self.assertIn("queen in gold", selections[0].stanzas[0])
        self.assertIn("princess arrayed", selections[2].stanzas[0])


class PsalmEditionCorpusTest(unittest.TestCase):
    def _usage(self):
        return PsalmUsage(
            usage_id="assumption_day",
            selection_id="ps45_10_11_12_16",
            territory="WORLD",
            date_rule="08-15",
            celebration_id="assumption",
            celebration_title="Assumption of the Blessed Virgin Mary",
            reading_set_kind="proper",
            reading_set_priority=1,
        )

    def _edition(self, edition_id, stanzas):
        return PsalmEditionText(
            selection_id="ps45_10_11_12_16",
            edition_id=edition_id,
            reference_normalized="ps45:10,11,12,16",
            response_text="The queen stands at your right hand, arrayed in gold.",
            stanzas=stanzas,
            source_url=f"repo://{edition_id}",
        )

    def test_wide_comparison_contains_full_text_from_two_editions(self):
        comparison = build_wide_comparison(
            usages=[self._usage()],
            edition_rows=[
                self._edition("local_rsvce", ("RSVCE stanza one.", "Stanza two.")),
                self._edition("local_nabre", ("NABRE stanza one.", "Stanza two.")),
            ],
            baseline_edition="local_rsvce",
        )
        row = comparison[0]
        self.assertEqual(row["selection_id"], "ps45_10_11_12_16")
        self.assertTrue(row["local_rsvce_stanzas_text"])
        self.assertTrue(row["local_nabre_stanzas_text"])
        self.assertEqual(row["complete_edition_count"], 2)
        self.assertEqual(row["comparison_status"], "comparison_ready")
        self.assertIn(
            row["local_nabre_difference_class"],
            {"exact", "punctuation_only", "translation_variant"},
        )

    def test_csv_round_trip_preserves_multiline_full_text(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "comparison.csv"
        expected = "First full stanza.\n\nSecond full stanza."
        write_csv_rows(
            path,
            [{"selection_id": "ps45", "local_rsvce_stanzas_text": expected}],
            fieldnames=("selection_id", "local_rsvce_stanzas_text"),
        )
        with path.open(encoding="utf-8", newline="") as handle:
            actual = next(csv.DictReader(handle))
        self.assertEqual(actual["local_rsvce_stanzas_text"], expected)

    def test_generated_comparison_has_two_complete_editions_everywhere(self):
        path = ROOT / "verification/psalm_sources/psalm_text_comparison.csv"
        with path.open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))
        self.assertGreater(len(rows), 500)
        self.assertTrue(
            all(int(row["complete_edition_count"]) >= 2 for row in rows)
        )
        self.assertTrue(
            all(row["comparison_status"] == "comparison_ready" for row in rows)
        )
        self.assertTrue(all(row["local_rsvce_stanzas_text"] for row in rows))
        self.assertTrue(all(row["local_nabre_stanzas_text"] for row in rows))
        report = json.loads(
            (
                ROOT
                / "verification/psalm_sources/responsorial_psalm_audit_report.json"
            ).read_text(encoding="utf-8")
        )
        self.assertEqual(report["conflicting_pack_row_count"], 0)
        self.assertEqual(report["invalid_hash_count"], 0)
        self.assertEqual(report["orphan_usage_count"], 0)
        self.assertEqual(
            report["comparison_ready_count"], report["unique_selection_count"]
        )
        self.assertEqual(report["insufficient_edition_count"], 0)

    def test_known_legacy_reference_corruptions_are_repaired(self):
        expected = {
            "Ps 23: 13a, 3b4, 5, 6": "ps23:1-3a,3b-4,5,6",
            "Ps 114:1-2, 3-4, 5-6, 8-9": "ps116:1-2,3-4,5-6,8-9",
            "Psalm 27.1, 2, 3, 13-15": "ps27:1,2,3,13-14",
            "Ps 67:2-3, 5-6 and 8": "ps67:2-3,5-6,8",
            "(Ps 122: 1-2.3-4ab.4cd-5.6-7.8-9 (R. sec 1)": (
                "ps122:1-2,3-4ab,4cd-5,6-7,8-9"
            ),
        }
        from scripts.psalm_sources.bible_databases import parse_selection

        for raw, normalized in expected.items():
            self.assertEqual(parse_selection(raw).normalized, normalized)

    def test_compact_historical_canticle_references_are_parsed(self):
        from scripts.psalm_sources.bible_databases import parse_selection

        expected = {
            "firstsamuel2:1,4-5": "1sam2:1,4-5",
            "firstchronicles29:10,11": "1chr29:10,11",
            "tobit13:2,3-4a": "tob13:2,3-4a",
            "daniel3:68,69": "dan3:68,69",
            "exod15:1-2": "ex15:1-2",
        }
        for raw, normalized in expected.items():
            self.assertEqual(parse_selection(raw).normalized, normalized)

    def test_rsvce_historical_canticle_versification_is_aligned(self):
        tob = extract_bible_selection(
            ROOT / "assets/rsvce.db",
            edition_id="local_rsvce",
            reference="Tobit 13:2, 3-4a, 6, 8",
        )
        daniel = extract_bible_selection(
            ROOT / "assets/rsvce.db",
            edition_id="local_rsvce",
            reference="Daniel 3:68, 69, 70, 71, 72, 73, 74",
        )
        self.assertEqual(len(tob.stanzas), 4)
        self.assertIn("he shows mercy", tob.stanzas[0])
        self.assertIn("ice and cold", daniel.stanzas_text)
        self.assertEqual(len(daniel.stanzas), 7)

    def test_nabre_merged_psalm_2_ending_is_available(self):
        row = extract_bible_selection(
            ROOT / "assets/nabre.db",
            edition_id="local_nabre",
            reference="Ps 2:6-7, 8-9, 10-12a",
        )
        self.assertEqual(len(row.stanzas), 3)
        self.assertIn("refuge", row.stanzas[-1])

    def test_cross_chapter_psalm_selection_is_preserved_and_extracted(self):
        row = extract_bible_selection(
            ROOT / "assets/rsvce.db",
            edition_id="local_rsvce",
            reference="Ps 42:2, 3; 43:3, 4",
        )
        self.assertEqual(row.reference_normalized, "ps42:2,3,43:3,4")
        self.assertEqual([group.chapter for group in parse_selection(
            "Ps 42:2, 3; 43:3, 4"
        ).groups], [42, 42, 43, 43])
        self.assertEqual(len(row.stanzas), 4)
        self.assertEqual(
            parse_selection("Ps 42.1-2, 3; 43.3, 4").normalized,
            "ps42:1-2,3,43:3,4",
        )


class PsalmSourcePackTest(unittest.TestCase):
    def _pack_row(self, text="Complete stanza text."):
        return RuntimePsalmPackRow(
            edition_id="local_rsvce",
            selection_id="ps45_10_11_12_16",
            territory="WORLD",
            celebration_id="",
            date_rule="",
            reading_set_kind="generic",
            sunday_cycle="",
            weekday_cycle="",
            lectionary_number="",
            reference_normalized="ps45:10,11,12,16",
            response_text="The queen stands at your right hand.",
            stanzas_text=text,
            source_url="repo://assets/rsvce.db",
            source_edition="RSVCE",
            display_priority=100,
        )

    def test_bible_pack_preserves_every_runtime_reference_alias(self):
        edition = PsalmEditionText(
            selection_id="ps149_1_2_3_4_5_6a_9b",
            edition_id="local_rsvce",
            reference_normalized="ps149:1-2,3-4,5-6a+9b",
            response_text="The Lord takes delight in his people.",
            stanzas=("Sing to the Lord a new song.",),
            source_url="repo://assets/rsvce.db",
        )

        rows = pack_rows_from_editions(
            [edition],
            reference_aliases={
                edition.selection_id: {
                    "ps149:1-2,3-4,5,6a,9b",
                    "ps149:1b-2,3-4,5-6a,9b",
                }
            },
        )["local_rsvce"]

        self.assertEqual(
            {row.reference_normalized for row in rows},
            {
                "ps149:1-2,3-4,5-6a+9b",
                "ps149:1-2,3-4,5,6a,9b",
                "ps149:1b-2,3-4,5-6a,9b",
            },
        )
        self.assertEqual(len(validate_source_pack(rows)), 3)

    def test_runtime_pack_rejects_conflicting_duplicate_selection(self):
        rows = [self._pack_row(text="First"), self._pack_row(text="Different")]
        with self.assertRaisesRegex(ValueError, "conflicting duplicate"):
            validate_source_pack(rows)

    def test_manifest_only_marks_nonempty_validated_packs_installed(self):
        raw = json.loads(
            (ROOT / "scripts/psalm_sources/source_registry.json").read_text(
                encoding="utf-8"
            )
        )
        registry = [SourceRecord.from_dict(item) for item in raw]
        manifest = build_manifest(
            registry=registry,
            packs={"local_rsvce": [self._pack_row()]},
        )
        self.assertTrue(manifest["local_rsvce"]["installed"])
        self.assertFalse(manifest["jerusalem_bible"]["installed"])

    def test_resolved_day_rows_preserve_date_and_choice_identity(self):
        source_rows = [
            PsalmSourceRow(
                usage_id=f"ng:2026-08-{day}:responsorial-psalm:1",
                celebration_id="",
                celebration_title="Weekday",
                date_rule=f"2026-08-{day}",
                season="",
                week="",
                weekday="",
                sunday_cycle="",
                weekday_cycle="II",
                lectionary_number="",
                territory="NG",
                reading_set_kind="resolved-day",
                reading_set_priority=1,
                biblical_book="Ps",
                psalm_number_hebrew="23",
                psalm_number_vulgate="22",
                reference_raw="Ps 23:1-3a, 3b-4, 5, 6",
                reference_normalized="ps23:1-3a,3b-4,5,6",
                stanza_selection_normalized="ps23:1-3a,3b-4,5,6",
                response_verse_normalized="1",
                source_id="nigeria_365_firestore",
                source_name="Catholic Missal for Nigeria",
                source_edition="live Nigerian daily corpus",
                source_territory="NG",
                source_url="https://example.invalid/nigeria",
                retrieved_at="2026-08-17",
                source_license="CBCN Ordo",
                reuse_status="licensed",
                response_raw=f"Response for August {day}.",
                response_normalized=f"response for august {day}",
                stanzas_raw=f"Complete stanza for August {day}.",
                stanzas_normalized=f"complete stanza for august {day}",
                raw_sha256="a" * 64,
                normalized_sha256="b" * 64,
                token_count=5,
            )
            for day in (18, 19)
        ]

        rows = pack_rows_from_source_rows(source_rows)

        self.assertEqual([row.date_rule for row in rows], ["2026-08-18", "2026-08-19"])
        self.assertEqual(
            [row.selection_id for row in rows],
            [
                "ng:2026-08-18:responsorial-psalm:1",
                "ng:2026-08-19:responsorial-psalm:1",
            ],
        )
        self.assertEqual(len(validate_source_pack(rows)), 2)

    def test_runtime_writer_installs_resolved_day_source_pack(self):
        source = self._sample_source_rows()
        source.append(
            replace(
                source[0],
                source_id="local_standard_lectionary",
                stanzas_raw="",
            )
        )
        registry = json.loads(
            (ROOT / "scripts/psalm_sources/source_registry.json").read_text(
                encoding="utf-8"
            )
        )
        records = [SourceRecord.from_dict(item) for item in registry]
        with tempfile.TemporaryDirectory() as directory:
            manifest = write_runtime_packs(
                Path(directory),
                registry=records,
                edition_rows=[],
                source_rows=source,
            )
            self.assertTrue(manifest["nigeria_365_firestore"]["installed"])
            self.assertEqual(
                manifest["nigeria_365_firestore"]["selectionCount"],
                2,
            )
            with (Path(directory) / "nigeria_365.csv").open(
                encoding="utf-8", newline=""
            ) as handle:
                self.assertEqual(len(list(csv.DictReader(handle))), 2)

    def test_reference_normalization_preserves_chapter_separator(self):
        self.assertEqual(
            normalize_reference("Dt 32.18-19, 20, 21"),
            "deuteronomy32:18-19,20,21",
        )
        self.assertEqual(
            normalize_reference("Ps 23:1-3a. 3b-4. 5. 6"),
            "ps23:1-3a,3b-4,5,6",
        )

    @staticmethod
    def _sample_source_rows():
        return [
            PsalmSourceRow(
                usage_id=f"ng:2026-08-{day}:responsorial-psalm:1",
                celebration_id="",
                celebration_title="Weekday",
                date_rule=f"2026-08-{day}",
                season="",
                week="",
                weekday="",
                sunday_cycle="",
                weekday_cycle="II",
                lectionary_number="",
                territory="NG",
                reading_set_kind="resolved-day",
                reading_set_priority=1,
                biblical_book="Ps",
                psalm_number_hebrew="23",
                psalm_number_vulgate="22",
                reference_raw="Ps 23:1-3a, 3b-4, 5, 6",
                reference_normalized="ps23:1-3a,3b-4,5,6",
                stanza_selection_normalized="ps23:1-3a,3b-4,5,6",
                response_verse_normalized="1",
                source_id="nigeria_365_firestore",
                source_name="Catholic Missal for Nigeria",
                source_edition="live Nigerian daily corpus",
                source_territory="NG",
                source_url="https://example.invalid/nigeria",
                retrieved_at="2026-08-17",
                source_license="CBCN Ordo",
                reuse_status="licensed",
                response_raw=f"Response for August {day}.",
                response_normalized=f"response for august {day}",
                stanzas_raw=f"Complete stanza for August {day}.",
                stanzas_normalized=f"complete stanza for august {day}",
                raw_sha256="a" * 64,
                normalized_sha256="b" * 64,
                token_count=5,
            )
            for day in (18, 19)
        ]

    def test_generated_manifest_only_installs_nonempty_validated_packs(self):
        root = ROOT / "assets/data/psalm_editions"
        manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
        editions = {row["id"]: row for row in manifest["editions"]}
        self.assertEqual(
            editions["local_rsvce"]["selectionCount"],
            editions["local_nabre"]["selectionCount"],
        )
        self.assertGreaterEqual(editions["local_rsvce"]["selectionCount"], 809)
        self.assertTrue(editions["nigeria_365_firestore"]["installed"])
        self.assertFalse(editions["modern_psalter_us"]["installed"])
        self.assertFalse(editions["jerusalem_bible"]["installed"])
        for filename in ("rsvce.csv", "nabre.csv", "nigeria_365.csv"):
            with (root / filename).open(encoding="utf-8", newline="") as handle:
                rows = list(csv.DictReader(handle))
            edition_id = {
                "rsvce.csv": "local_rsvce",
                "nabre.csv": "local_nabre",
                "nigeria_365.csv": "nigeria_365_firestore",
            }[filename]
            self.assertEqual(len(rows), editions[edition_id]["selectionCount"])
            self.assertTrue(rows)
            self.assertTrue(all(row["stanzas_text"].strip() for row in rows))
            self.assertTrue(all(len(row["raw_sha256"]) == 64 for row in rows))
            if filename != "nigeria_365.csv":
                self.assertIn(
                    "deut32:18-19,20,21",
                    {row["reference_normalized"] for row in rows},
                )

    def test_nigeria_manifest_uses_exact_public_name(self):
        manifest = json.loads(
            (ROOT / "assets/data/psalm_editions/manifest.json").read_text(
                encoding="utf-8"
            )
        )
        nigeria = next(
            row
            for row in manifest["editions"]
            if row["id"] == "nigeria_365_firestore"
        )
        self.assertEqual(
            nigeria["displayName"],
            "Catholic Missal for Nigeria",
        )

    def test_nigeria_usage_and_text_selection_counts_are_separate(self):
        usage_path = ROOT / "assets/data/nigeria_psalm_usages.csv"
        pack_path = ROOT / "assets/data/psalm_editions/nigeria_365.csv"
        with usage_path.open(encoding="utf-8-sig", newline="") as handle:
            usages = list(csv.DictReader(handle))
        with pack_path.open(encoding="utf-8-sig", newline="") as handle:
            texts = list(csv.DictReader(handle))

        self.assertGreater(len(usages), len(texts))
        self.assertTrue(all(row["usage_id"] for row in usages))
        self.assertTrue(all(row["selection_id"] for row in texts))

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
    def test_known_ocr_reference_errors_are_canonicalized(self):
        self.assertEqual(
            canonicalize_nigeria_reference(
                "2025-12-13", "ps50:2ac,3b,15-16a.i5-19"
            ),
            "Ps 80:2ac, 3b, 15-16a, 18-19",
        )
        self.assertEqual(
            canonicalize_nigeria_reference(
                "2025-12-28", "ps125:1-2,3,4-5)"
            ),
            "Ps 128:1-2, 3, 4-5",
        )
        self.assertEqual(
            canonicalize_nigeria_reference(
                "2025-12-31", "ps9:1-2,11-12,13)"
            ),
            "Ps 96:1-2, 11-12, 13",
        )
        self.assertEqual(
            canonicalize_nigeria_reference(
                "2026-11-21", "ps114:1,2,9-10"
            ),
            "Ps 144:1, 2, 9-10",
        )

    def test_bundled_nigeria_references_have_no_residual_ocr_ranges(self):
        with (ROOT / "assets/data/psalm_editions/nigeria_365.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = list(csv.DictReader(handle))
        problems = []
        for row in rows:
            reference = row["reference_normalized"]
            if "(" in reference or ")" in reference:
                problems.append((row["date_rule"], reference))
            body = reference.split(":", maxsplit=1)[-1]
            for group in body.replace(";", ",").split(","):
                match = re.match(r"\s*(\d+)[a-z]*-(\d+)", group)
                if match and int(match.group(2)) < int(match.group(1)):
                    problems.append((row["date_rule"], reference))
        self.assertEqual(problems, [])

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

    @patch("scripts.psalm_sources.nigeria_365.urlopen")
    def test_live_fetch_retries_a_transient_connection_reset(self, urlopen):
        response = MagicMock()
        response.__enter__.return_value.read.return_value = b'{"documents": []}'
        urlopen.side_effect = [URLError("connection reset"), response]

        page = fetch_live_page(None)

        self.assertEqual(page, {"documents": []})
        self.assertEqual(urlopen.call_count, 2)

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

    def test_ocr_heading_variants_are_not_silently_skipped(self):
        variants = [
            ("21-01-2026", "RESONSORIAL PSALM   PS 144:1.2.9-10 (R 1a)"),
            ("25-01-2026", "RESPONSORAL PSALM - Psalm 27:1.4.13-14 (R. 1a)"),
            ("29-04-2026", "RESPONSOR IAL PSALM Psalm 67:2-3.5.6 and 8 (R. 4)"),
            ("18-06-2026", "RESPONSORI AL PSALM Psalm 97:1-2.3-4.5-6.7 (R. 12a)"),
            ("16-08-2026", "RESPONSORIAL PSLAM Ps 67:2-3.5.6.8 (R. 4)"),
            ("24-08-2026", "RESPON SORIAL PSALM Ps 145:10-11.12-13ab.17-18"),
            ("07-09-2026", "RESPON SORIAL PSALM Psalm 5:5-6.7.12 (R. 9a)"),
        ]
        page = {
            "documents": [
                {
                    "fields": {
                        "mandroiddates": {"stringValue": date},
                        "title": {"stringValue": f"Fixture {date}\nWeekday"},
                        "body": {
                            "stringValue": (
                                f"{heading}\n"
                                "R/. A verified response.\n\n"
                                "A complete stanza line. R/.\n\n"
                                "ALLELUIA John 14:6\n"
                            )
                        },
                    }
                }
                for date, heading in variants
            ]
        }

        rows = extract_rows(page)

        self.assertEqual(
            [row.date_rule for row in rows],
            [
                "2026-01-21",
                "2026-01-25",
                "2026-04-29",
                "2026-06-18",
                "2026-08-16",
                "2026-08-24",
                "2026-09-07",
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

    def test_year_two_week_twenty_monday_uses_deuteronomy_canticle(self):
        with (ROOT / "standard_lectionary_complete.csv").open(
            encoding="utf-8-sig", newline=""
        ) as handle:
            rows = list(csv.DictReader(handle))
        matches = [
            row
            for row in rows
            if row["season"] == "Ordinary Time"
            and row["week"] == "20"
            and row["day"] == "Monday"
            and row["weekday_cycle"] == "II"
        ]
        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0]["first_reading"], "Ezek 24.15-24")
        self.assertEqual(
            matches[0]["psalm_reference"],
            "Dt 32.18-19, 20, 21",
        )
        self.assertEqual(
            matches[0]["psalm_response"],
            "You forgot God who gave you birth.",
        )
        self.assertEqual(matches[0]["gospel"], "Matt 19.16-22")

    def test_ordinary_time_week_metadata_matches_lectionary_number(self):
        day_offsets = {
            "Monday": 299,
            "Tuesday": 300,
            "Wednesday": 301,
            "Thursday": 302,
            "Friday": 303,
            "Saturday": 304,
        }
        with (ROOT / "standard_lectionary_complete.csv").open(
            encoding="utf-8-sig", newline=""
        ) as handle:
            rows = list(csv.DictReader(handle))
        mismatches = []
        for line_number, row in enumerate(rows, start=2):
            if row["season"] != "Ordinary Time" or row["day"] not in day_offsets:
                continue
            if not row["lectionary_number"].isdigit():
                continue
            lectionary_number = int(row["lectionary_number"])
            delta = lectionary_number - day_offsets[row["day"]]
            if delta < 6 or delta > 204 or delta % 6:
                continue
            expected_week = str(delta // 6)
            if row["week"] != expected_week:
                mismatches.append(
                    (line_number, row["week"], expected_week, lectionary_number)
                )
        self.assertEqual(mismatches, [])


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


class NigeriaPsalmUsageCatalogTest(unittest.TestCase):
    def setUp(self):
        self.source_rows = PsalmSourcePackTest._sample_source_rows()

    def test_builds_temporal_usage_without_using_source_date_as_key(self):
        source = self.source_rows[0]
        assignments = [
            NigeriaPsalmUsageAssignment(
                source_selection_id=source.usage_id,
                territory="NG",
                kind="temporal",
                season="ordinary",
                week="20",
                weekday="tuesday",
                weekday_cycle="II",
                choice_priority=1,
                review_status="verified",
            )
        ]

        rows = build_nigeria_usage_catalog([source], assignments)

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].source_date, "2026-08-18")
        self.assertEqual(rows[0].stable_key, "NG|temporal|ordinary|20|tuesday||II")
        self.assertNotIn("2026-08-18", rows[0].stable_key)
        self.assertEqual(rows[0].reference_normalized, "ps23:1-3a,3b-4,5,6")

    def test_advent_weekday_cycle_uses_the_new_liturgical_year(self):
        context = temporal_context(date(2025, 12, 1))

        self.assertEqual(context.sunday_cycle, "")
        self.assertEqual(context.weekday_cycle, "II")

    def test_requires_a_reviewed_disposition_for_every_source_choice(self):
        source = self.source_rows[0]
        with self.assertRaisesRegex(ValueError, "missing assignment"):
            build_nigeria_usage_catalog([source], [])

        excluded = NigeriaPsalmUsageAssignment(
            source_selection_id=source.usage_id,
            territory="NG",
            kind="excluded",
            exclusion_reason="duplicate publisher row",
            review_status="verified",
        )
        self.assertEqual(build_nigeria_usage_catalog([source], [excluded]), ())

    def test_rejects_ambiguous_or_incomplete_stable_keys(self):
        source_a, source_b = self.source_rows
        incomplete = NigeriaPsalmUsageAssignment(
            source_selection_id=source_a.usage_id,
            territory="NG",
            kind="temporal",
            season="ordinary",
            week="20",
            weekday="tuesday",
            review_status="verified",
        )
        with self.assertRaisesRegex(ValueError, "cycle"):
            build_nigeria_usage_catalog([source_a], [incomplete])

        duplicate_assignments = [
            NigeriaPsalmUsageAssignment(
                source_selection_id=source.usage_id,
                territory="NG",
                kind="celebration",
                celebration_id="assumption_of_the_blessed_virgin_mary",
                mass_form="day",
                choice_priority=1,
                review_status="verified",
            )
            for source in (source_a, source_b)
        ]
        with self.assertRaisesRegex(ValueError, "ambiguous stable key"):
            build_nigeria_usage_catalog(
                [source_a, source_b],
                duplicate_assignments,
            )

    def test_validator_rejects_unverified_display_rows(self):
        source = self.source_rows[0]
        assignment = NigeriaPsalmUsageAssignment(
            source_selection_id=source.usage_id,
            territory="NG",
            kind="celebration",
            celebration_id="assumption_of_the_blessed_virgin_mary",
            mass_form="day",
            review_status="unreviewed",
        )
        with self.assertRaisesRegex(ValueError, "not verified"):
            validate_nigeria_usage_catalog(
                build_nigeria_usage_catalog(
                    [source],
                    [assignment],
                    validate=False,
                )
            )


class NigeriaHistoricalPsalmInventoryTest(unittest.TestCase):
    def test_historical_reference_comparison_ignores_response_locators_and_parts(self):
        from scripts.psalm_sources.nigeria_archive import (
            selection_reference,
            selection_signature,
        )

        leaf = "ps98:1,7-9ab,9cd(r.3cd)"
        gallery = "ps98:1,7-8,9"
        self.assertEqual(selection_reference(leaf), "ps98:1,7-9ab,9cd")
        self.assertEqual(
            selection_reference("ps103:1-2,11-12,19-20abr.(19a)"),
            "ps103:1-2,11-12,19-20ab",
        )
        self.assertEqual(
            selection_signature("ps78:3&4bc,6c-7,8(r.7b)"),
            selection_signature("ps78:3,4bc,6c-7,8"),
        )
        self.assertEqual(
            selection_signature(leaf),
            selection_signature(gallery),
        )
        self.assertNotEqual(
            selection_signature("ps57:2,3-4,6,11"),
            selection_signature("ps80:2-3,5-7"),
        )

    def test_historical_cycles_and_propers_use_stable_liturgical_keys(self):
        year_b = temporal_context(date(2024, 2, 4))
        year_c = temporal_context(date(2025, 2, 2))
        weekday_i = temporal_context(date(2025, 8, 18))
        self.assertEqual(year_b.sunday_cycle, "B")
        self.assertEqual(year_c.sunday_cycle, "C")
        self.assertEqual(weekday_i.weekday_cycle, "I")

        assumption = replace(
            PsalmSourcePackTest._sample_source_rows()[0],
            usage_id="history:2024-08-15:1",
            date_rule="2024-08-15",
            reference_normalized="ps45:10,11,12,16",
            response_raw="On your right stands the queen in gold of Ophir.",
        )
        assignments, unresolved = infer_nigeria_assignments(
            [assumption],
            root=ROOT,
        )
        self.assertFalse(unresolved)
        self.assertEqual(assignments[0].kind, "celebration")
        self.assertEqual(
            assignments[0].celebration_id,
            "the_assumption_of_the_blessed_virgin_mary",
        )
        self.assertEqual(assignments[0].mass_form, "day")

    def test_historical_assignments_honor_transfers_and_sunday_precedence(self):
        sample = PsalmSourcePackTest._sample_source_rows()[0]
        rows = [
            replace(
                sample,
                usage_id="history:2024-03-25:1",
                date_rule="2024-03-25",
                reference_normalized="ps27:1,2,3,13-14",
                response_raw="The Lord is my light and my salvation.",
            ),
            replace(
                sample,
                usage_id="history:2024-04-08:1",
                date_rule="2024-04-08",
                reference_normalized="ps40:7-8a,8b-9,10,11",
                response_raw="See, I have come, Lord, to do your will.",
            ),
            replace(
                sample,
                usage_id="history:2024-09-08:1",
                date_rule="2024-09-08",
                reference_normalized="ps146:6c-7,8-9a,9bc-10",
                response_raw="Praise the Lord, my soul!",
            ),
            replace(
                sample,
                usage_id="history:2025-08-10:1",
                date_rule="2025-08-10",
                reference_normalized="ps33:1,12,18-19,20-22",
                response_raw="Blessed the people the Lord has chosen as his heritage.",
            ),
        ]
        assignments, unresolved = infer_nigeria_assignments(rows, root=ROOT)
        self.assertFalse(unresolved)
        self.assertEqual(assignments[0].kind, "special-period")
        self.assertEqual(assignments[0].special_day, "holy-week-monday")
        self.assertEqual(assignments[1].kind, "celebration")
        self.assertEqual(assignments[1].celebration_id, "annunciation_of_the_lord")
        self.assertEqual(assignments[2].kind, "temporal")
        self.assertEqual(assignments[2].sunday_cycle, "B")
        self.assertEqual(assignments[3].kind, "temporal")
        self.assertEqual(assignments[3].sunday_cycle, "C")

    def test_parses_historical_response_and_full_psalm_sources(self):
        from scripts.psalm_sources.nigeria_archive import (
            parse_catholic_gallery_psalm,
            parse_catholic_leaf_psalm,
            parse_universalis_calendar,
        )

        leaf = parse_catholic_leaf_psalm(
            """
            <h2>15th August 2024 (Thursday)</h2>
            <h3>Psalm 45:10, 11, 12, 16 (R. 10b)</h3>
            <p>R/. On your right stands the queen in gold of Ophir.</p>
            """,
            source_url="https://example.test/leaf",
        )
        self.assertEqual(leaf.date_rule, "2024-08-15")
        self.assertEqual(leaf.reference_normalized, "ps45:10,11,12,16(r.10b)")
        self.assertEqual(
            leaf.response_raw,
            "On your right stands the queen in gold of Ophir.",
        )
        self.assertFalse(leaf.stanzas_raw)

        gallery = parse_catholic_gallery_psalm(
            """
            <h2>Responsorial Psalm: Psalms 67: 2-3, 5, 6, 8</h2>
            <p><strong>R. (2a) May God bless us in his mercy.</strong></p>
            <p>2 May God have mercy on us, and bless us.<br>3 That we may know thy way upon earth.</p>
            <p>R. May God bless us in his mercy.</p>
            <p>5 Let the nations be glad and rejoice.</p>
            <h2>Second Reading: Galatians 4: 4-7</h2>
            """,
            source_url="https://www.catholicgallery.org/mass-reading/010124/",
        )
        self.assertEqual(gallery.date_rule, "2024-01-01")
        self.assertEqual(gallery.reference_normalized, "ps67:2-3,5,6,8")
        self.assertEqual(gallery.response_raw, "May God bless us in his mercy.")
        self.assertIn("May God have mercy on us", gallery.stanzas_raw)
        self.assertIn("Let the nations be glad", gallery.stanzas_raw)

        calendar = parse_universalis_calendar(
            """
            <tr><th colspan="2">January</th></tr>
            <tr><td valign="top">Mon&#160;1</td><td><span>Mary, the Holy Mother of God</span> <span>Solemnity</span></td></tr>
            <tr><td valign="top">Tue&#160;2</td><td>Saints Basil the Great and Gregory Nazianzen</td></tr>
            """,
            year=2024,
        )
        self.assertEqual(calendar["2024-01-01"], "Mary, the Holy Mother of God Solemnity")
        self.assertEqual(
            calendar["2024-01-02"],
            "Saints Basil the Great and Gregory Nazianzen",
        )

    def test_every_2024_2025_date_has_an_explicit_evidence_status(self):
        inventory_path = (
            ROOT
            / "verification/psalm_sources/nigeria_2024_2025_source_inventory.csv"
        )
        self.assertTrue(inventory_path.exists(), "historical source inventory is missing")

        with inventory_path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))

        expected_dates = []
        cursor = date(2024, 1, 1)
        end = date(2025, 11, 30)
        while cursor <= end:
            expected_dates.append(cursor.isoformat())
            cursor += timedelta(days=1)

        self.assertEqual([row["date"] for row in rows], expected_dates)
        self.assertTrue(
            all(
                row["primary_source_status"]
                in {"recovered", "not_in_current_live_collection", "unavailable"}
                for row in rows
            )
        )
        self.assertTrue(all(row["verification_status"] != "pending" for row in rows))

    def test_historical_assignments_report_new_corroborated_and_conflict_keys(self):
        path = (
            ROOT
            / "verification/psalm_sources/nigeria_2024_2025_usage_assignments.csv"
        )
        self.assertTrue(path.exists(), "historical stable-key assignments are missing")
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))

        self.assertEqual(len(rows), 700)
        self.assertTrue(all(row["stable_usage_key"] for row in rows))
        self.assertTrue(
            all("(" not in row["selected_reference"] for row in rows)
        )
        self.assertTrue(
            all(row["source_date"] not in row["stable_usage_key"] for row in rows)
        )
        statuses = {row["reconciliation_status"] for row in rows}
        self.assertEqual(
            statuses,
            {"corroborates_runtime_key", "conflict_review_required"},
        )
        self.assertTrue(any(row["sunday_cycle"] == "B" for row in rows))
        self.assertTrue(any(row["sunday_cycle"] == "C" for row in rows))
        self.assertTrue(any(row["weekday_cycle"] == "I" for row in rows))

    def test_runtime_catalog_contains_all_nonconflicting_historical_keys(self):
        def stable_key(row):
            if row["kind"] == "temporal":
                values = (
                    row["territory"], row["kind"], row["season"], row["week"],
                    row["weekday"], row["sunday_cycle"], row["weekday_cycle"],
                )
            elif row["kind"] == "celebration":
                values = (
                    row["territory"], row["kind"], row["celebration_id"],
                    row["mass_form"], row["sunday_cycle"], row["weekday_cycle"],
                )
            else:
                values = (
                    row["territory"], row["kind"], row["special_day"],
                    row["mass_form"], row["sunday_cycle"], row["weekday_cycle"],
                )
            return "|".join(values)

        with (
            ROOT
            / "verification/psalm_sources/nigeria_2024_2025_usage_assignments.csv"
        ).open(encoding="utf-8-sig", newline="") as handle:
            historical = list(csv.DictReader(handle))
        with (ROOT / "assets/data/nigeria_psalm_usages.csv").open(
            encoding="utf-8-sig", newline=""
        ) as handle:
            runtime = list(csv.DictReader(handle))

        expected = {
            row["stable_usage_key"]
            for row in historical
            if row["reconciliation_status"] != "conflict_review_required"
        }
        actual = {stable_key(row) for row in runtime}
        self.assertTrue(expected)
        self.assertTrue(expected <= actual)

    def test_conflicting_historical_choices_are_quarantined(self):
        with (
            ROOT
            / "verification/psalm_sources/nigeria_2024_2025_usage_assignments.csv"
        ).open(encoding="utf-8-sig", newline="") as handle:
            historical = list(csv.DictReader(handle))
        conflicts = {
            (
                row["stable_usage_key"],
                normalize_selection_reference(row["selected_reference"]),
                normalize_words(row["selected_response"]),
            )
            for row in historical
            if row["reconciliation_status"] == "conflict_review_required"
        }
        history_targets = {
            (
                row.stable_key,
                row.reference_normalized,
                normalize_words(row.response_text),
            )
            for row in build_liturgical_usage_universe(ROOT)
            if row.source_catalog == "nigeria_2024_2025_usage_assignments.csv"
        }
        self.assertTrue(conflicts)
        self.assertTrue(conflicts.isdisjoint(history_targets))

    def test_historical_comparison_contains_two_full_text_editions(self):
        comparison_path = (
            ROOT / "verification/psalm_sources/nigeria_2024_2025_comparison.csv"
        )
        self.assertTrue(comparison_path.exists(), "historical comparison is missing")
        with comparison_path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))

        self.assertEqual(len(rows), 700)
        self.assertTrue(
            all(
                row["douay_rheims_full_text"] and row["rsvce_full_text"]
                for row in rows
                if row["comparison_status"] != "unavailable"
            )
        )
        self.assertTrue(all(row["stable_usage_key"] for row in rows))
        self.assertTrue(all(row["source_date"] not in row["stable_usage_key"] for row in rows))


class LiturgicalUsageUniverseTest(unittest.TestCase):
    def test_universe_covers_cycles_propers_forms_and_alternatives(self):
        rows = validate_liturgical_usage_universe(
            build_liturgical_usage_universe(ROOT)
        )

        self.assertGreater(len(rows), 800)
        self.assertEqual(
            {row.sunday_cycle for row in rows if row.sunday_cycle},
            {"A", "B", "C"},
        )
        self.assertEqual(
            {row.weekday_cycle for row in rows if row.weekday_cycle},
            {"I", "II"},
        )
        self.assertTrue(
            any(
                row.celebration_id
                == "the_assumption_of_the_blessed_virgin_mary"
                and row.mass_form == "vigil"
                for row in rows
            )
        )
        self.assertTrue(any(row.choice_priority > 1 for row in rows))
        self.assertTrue(all(not row.date_rule for row in rows))

    def test_universe_has_unique_stable_key_and_priority_pairs(self):
        rows = validate_liturgical_usage_universe(
            build_liturgical_usage_universe(ROOT)
        )
        pairs = [(row.stable_key, row.choice_priority) for row in rows]
        self.assertEqual(len(pairs), len(set(pairs)))

    def test_every_structured_lectionary_psalm_is_in_the_universe(self):
        rows = validate_liturgical_usage_universe(
            build_liturgical_usage_universe(ROOT)
        )
        with (ROOT / "standard_lectionary_complete.csv").open(
            encoding="utf-8-sig", newline=""
        ) as handle:
            standard = list(csv.DictReader(handle))
        expected = set()
        for row in standard:
            if not row["psalm_reference"].strip():
                continue
            source_title = row["source_title"].strip().upper()
            if source_title.startswith(
                ("EASTER VIGIL", "SECOND SUNDAY AFTER CHRISTMAS")
            ):
                continue
            if (
                row["season"].strip().lower() == "christmas"
                and row["week"].strip().lower() == "octave"
                and not row["day"].strip().lower().startswith("january ")
            ):
                continue
            expected.add(normalize_selection_reference(row["psalm_reference"]))
        actual = {row.reference_normalized for row in rows}
        self.assertTrue(expected <= actual)


class CompleteNigeriaCoverageTest(unittest.TestCase):
    def test_complete_comparison_has_all_usages_and_two_text_editions(self):
        def rows(path):
            with path.open(encoding="utf-8-sig", newline="") as handle:
                return list(csv.DictReader(handle))

        coverage = rows(
            ROOT
            / "verification/psalm_sources/nigeria_complete_liturgical_coverage.csv"
        )
        comparison = rows(
            ROOT
            / "verification/psalm_sources/nigeria_complete_psalm_text_comparison.csv"
        )
        expected = {
            (row["stable_usage_key"], row["choice_priority"])
            for row in coverage
        }
        actual = {
            (row["stable_usage_key"], row["choice_priority"])
            for row in comparison
        }
        self.assertEqual(actual, expected)
        self.assertTrue(all(row["rsvce_text"] for row in comparison))
        self.assertTrue(all(row["nabre_text"] for row in comparison))
        self.assertTrue(
            all(
                row["nigeria_text"]
                for row in comparison
                if row["resolution_status"]
                in {"exact_nigeria", "reconstructed_nigeria"}
            )
        )

    def test_every_usage_choice_has_provenance_and_resolution_status(self):
        path = (
            ROOT
            / "verification/psalm_sources/nigeria_complete_liturgical_coverage.csv"
        )
        self.assertTrue(path.exists())
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))

        self.assertGreater(len({row["stable_usage_key"] for row in rows}), 1000)
        self.assertTrue(all(row["reference_normalized"] for row in rows))
        self.assertTrue(all(row["response_text"] for row in rows))
        self.assertTrue(
            all(
                row["resolution_status"]
                in {
                    "exact_nigeria",
                    "reconstructed_nigeria",
                    "fallback",
                    "conflict",
                    "missing",
                }
                for row in rows
            )
        )
        self.assertTrue(all(row["source_catalog"] for row in rows))

    def test_catholicgallery_is_reference_evidence_not_nigeria_text(self):
        path = (
            ROOT
            / "verification/psalm_sources/nigeria_complete_liturgical_coverage.csv"
        )
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))

        gallery = [row for row in rows if row["gallery_source_url"]]
        self.assertTrue(gallery)
        self.assertTrue(
            all(row["gallery_text_edition"] == "Douay-Rheims" for row in gallery)
        )
        self.assertTrue(
            all(
                not (
                    row["display_edition"] == "Catholic Missal for Nigeria"
                    and row["text_source_id"]
                    == "catholic_gallery_douay_archive"
                )
                for row in rows
            )
        )

    def test_coverage_summary_matches_the_csv(self):
        csv_path = (
            ROOT
            / "verification/psalm_sources/nigeria_complete_liturgical_coverage.csv"
        )
        json_path = (
            ROOT
            / "verification/psalm_sources/nigeria_complete_liturgical_coverage.json"
        )
        with csv_path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        summary = json.loads(json_path.read_text(encoding="utf-8"))

        self.assertEqual(summary["ordered_choices"], len(rows))
        self.assertEqual(
            summary["stable_usages"],
            len({row["stable_usage_key"] for row in rows}),
        )
        self.assertEqual(
            summary["distinct_references"],
            len({row["reference_normalized"] for row in rows}),
        )


class NigeriaTextReconstructionTest(unittest.TestCase):
    def test_exact_selection_is_preferred_to_fragment_reconstruction(self):
        rows = load_nigeria_pack(
            ROOT / "assets/data/psalm_editions/nigeria_365.csv"
        )
        exact = rows[0]
        result = reconstruct_nigeria_selection(
            exact.reference_normalized,
            exact.response_text,
            rows,
            build_verified_fragment_index(rows),
        )

        self.assertEqual(result.status, "exact_nigeria")
        self.assertEqual(result.stanzas_text, exact.stanzas_text)
        self.assertEqual(result.source_selection_ids, (exact.selection_id,))

    def test_verified_fragments_can_reconstruct_a_missing_selection(self):
        first = RuntimePsalmPackRow(
            edition_id="nigeria_365_firestore",
            selection_id="ng:first",
            territory="NG",
            celebration_id="",
            date_rule="2025-01-01",
            reading_set_kind="resolved-day",
            sunday_cycle="",
            weekday_cycle="I",
            lectionary_number="",
            reference_normalized="ps23:1-2,3-4",
            response_text="The Lord is my shepherd.",
            stanzas_text="First verified stanza.\n\nSecond verified stanza.",
            source_url="https://example.invalid/first",
            source_edition="live Nigerian daily corpus",
            display_priority=1,
        )
        second = RuntimePsalmPackRow(
            edition_id="nigeria_365_firestore",
            selection_id="ng:second",
            territory="NG",
            celebration_id="",
            date_rule="2025-01-02",
            reading_set_kind="resolved-day",
            sunday_cycle="",
            weekday_cycle="I",
            lectionary_number="",
            reference_normalized="ps23:5,6",
            response_text="The Lord is my shepherd.",
            stanzas_text="Third verified stanza.\n\nFourth verified stanza.",
            source_url="https://example.invalid/second",
            source_edition="live Nigerian daily corpus",
            display_priority=1,
        )
        rows = (first, second)

        result = reconstruct_nigeria_selection(
            "ps23:1-2,3-4,5,6",
            "The Lord is my shepherd.",
            rows,
            build_verified_fragment_index(rows),
        )

        self.assertEqual(result.status, "reconstructed_nigeria")
        self.assertEqual(
            result.stanzas_text,
            "First verified stanza.\n\nSecond verified stanza.\n\n"
            "Third verified stanza.\n\nFourth verified stanza.",
        )
        self.assertEqual(result.source_selection_ids, ("ng:first", "ng:second"))

    def test_incomplete_or_conflicting_fragments_do_not_create_nigeria_text(self):
        result = reconstruct_nigeria_selection(
            "ps999:1-4",
            "A response.",
            (),
            {},
        )

        self.assertEqual(result.status, "fallback")
        self.assertEqual(result.stanzas_text, "")
        self.assertEqual(result.source_selection_ids, ())

    def test_generated_nigeria_pack_contains_only_complete_verified_text(self):
        path = ROOT / "assets/data/psalm_editions/nigeria_365.csv"
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))

        self.assertTrue(rows)
        self.assertTrue(
            any(
                row["source_edition"] == "verified Nigerian fragments"
                for row in rows
            )
        )
        self.assertTrue(
            all(row["edition_id"] == "nigeria_365_firestore" for row in rows)
        )
        self.assertTrue(all(row["response_text"].strip() for row in rows))
        self.assertTrue(all(row["stanzas_text"].strip() for row in rows))
        self.assertEqual(
            len(rows),
            len({row["selection_id"] for row in rows}),
        )

        coverage = json.loads(
            (
                ROOT
                / "verification/psalm_sources/nigeria_2024_2025_coverage.json"
            ).read_text(encoding="utf-8")
        )
        self.assertEqual(coverage["comparison_rows_with_two_full_texts"], 700)
        self.assertEqual(
            coverage["reference_counts"]["current_runtime_2025_2026"],
            {
                "unique_base_compositions": 137,
                "unique_exact_references": 921,
                "unique_numbered_verse_selections": 650,
            },
        )
        self.assertEqual(
            coverage["reference_counts"]["catholic_gallery_2024_2025"],
            {
                "unique_base_compositions": 132,
                "unique_exact_references": 456,
                "unique_numbered_verse_selections": 408,
            },
        )
        self.assertEqual(
            coverage["reference_counts"]["combined_runtime_and_gallery"],
            {
                "unique_base_compositions": 137,
                "unique_exact_references": 940,
                "unique_numbered_verse_selections": 660,
            },
        )


if __name__ == "__main__":
    unittest.main()
