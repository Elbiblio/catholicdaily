import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.psalm_sources.models import ReuseStatus, SourceRecord
from scripts.psalm_sources.normalize import (
    normalize_reference,
    parse_responsorial_section,
)
from scripts.psalm_sources.nigeria_365 import (
    extract_rows,
    iter_firestore_documents,
)


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


class PsalmNormalizationTest(unittest.TestCase):
    def test_reference_normalization_preserves_verse_parts(self):
        left = normalize_reference("Psalm 45:10.11.12.16 (R.10b)")
        right = normalize_reference("Ps 45:10, 11, 12, 16 (R. 10b)")
        self.assertEqual(left, right)
        self.assertNotEqual(
            left,
            normalize_reference("Ps 45:10, 11, 12, 16 (R. 10)"),
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


if __name__ == "__main__":
    unittest.main()
