import sys
import types
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

# The builder's extraction dependency is only needed when rebuilding the full
# catalog. These unit tests exercise its pure cleanup helpers, so provide the
# import surface without loading source PDFs.
weekday_parser = types.ModuleType("parse_weekday_lectionary")
weekday_parser.determine_cycle_from_context = lambda entries, _cycle: entries
weekday_parser.extract_entries = lambda _parsed, pdf_label="": []
weekday_parser.parse_full_text = lambda _path: []
sys.modules["parse_weekday_lectionary"] = weekday_parser

from standard_lectionary_builder import clean_reference, extract_acclamation_text


class StandardLectionaryAcclamationBuilderTest(unittest.TestCase):
    def test_repairs_known_reference_extraction_forms(self):
        cases = {
            "Corinthians 8.9": "2 Corinthians 8:9",
            "cf. 2 Thes 2:14": "cf. 2 Thess 2:14",
            "cf. 2 Tm 1:10": "cf. 2 Tim 1:10",
            "Jas 1:18": "James 1:18",
            "Joel 2; 12-13": "Joel 2:12-13",
            "John 63b, 68b": "John 6:63b, 68b",
            "Luke 21,28": "Luke 21:28",
        }

        for raw, expected in cases.items():
            with self.subTest(raw=raw):
                self.assertEqual(clean_reference(raw), expected)

    def test_strips_rubrics_and_page_markers_from_acclamation_text(self):
        cases = {
            "Jesus Christ was rich but he became poor. TUESDAY 1563":
                "Jesus Christ was rich but he became poor.",
            "God loved the world so much. 518 SECOND WEEK OF EASTER":
                "God loved the world so much.",
            "If the acclamation is not sung, it is omitted. "
            "Your words, Lord, are spirit and life.":
                "Your words, Lord, are spirit and life.",
        }

        for raw, expected in cases.items():
            with self.subTest(raw=raw):
                self.assertEqual(extract_acclamation_text([raw]), expected)


if __name__ == "__main__":
    unittest.main()
