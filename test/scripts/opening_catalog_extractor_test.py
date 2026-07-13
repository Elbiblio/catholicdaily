import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


def load_extractor():
    repo_root = Path(__file__).resolve().parents[2]
    script = repo_root / "scripts" / "active" / "extract_opening_catalog.py"
    spec = importlib.util.spec_from_file_location("extract_opening_catalog", script)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class OpeningCatalogExtractorTest(unittest.TestCase):
    def test_builds_opening_catalog_entries_from_source_markers(self):
        extractor = load_extractor()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source.txt"
            source.write_text(
                "\n".join(
                    [
                        "HEADER",
                        "FIRST READING Example 1.1-2",
                        "This is the source opening text. It continues with enough words "
                        "to be useful as a fingerprint for matching later renderings.",
                        "The word of the Lord.",
                    ]
                ),
                encoding="utf-8",
            )
            fixtures = root / "fixtures.json"
            fixtures.write_text(
                json.dumps(
                    [
                        {
                            "id": "fixture-1",
                            "date": "2026-07-15",
                            "region": "GB_EW",
                            "bibleVersion": "rsvce",
                            "reference": "Example 1:1-2",
                            "position": "First Reading",
                            "sourceLabel": "unit test source",
                            "sourcePath": "source.txt",
                            "startMarker": "FIRST READING Example 1.1-2",
                            "contentStartMarker": "This is the source opening",
                            "endMarker": "The word of the Lord.",
                        }
                    ]
                ),
                encoding="utf-8",
            )

            entries = extractor.build_catalog_entries(fixtures, root)

        self.assertEqual(len(entries), 1)
        entry = entries[0]
        self.assertEqual(entry["id"], "fixture-1")
        self.assertEqual(entry["key"], "GB_EW|2026-07-15|rsvce|first|Example 1:1-2")
        self.assertEqual(entry["slot"], "first")
        self.assertEqual(entry["copyrightMode"], "audit_only")
        self.assertLessEqual(len(entry["opening100"]), 100)
        self.assertLessEqual(len(entry["opening200"]), 200)
        self.assertIn("source opening text", entry["opening200"])
        self.assertEqual(
            entry["normalizedFingerprint"],
            "this is the source opening text it continues with enough words "
            "to be useful as a fingerprint for matching later renderings",
        )
        self.assertRegex(entry["sha256"], r"^[0-9a-f]{64}$")

    def test_writes_jsonl_output(self):
        extractor = load_extractor()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source.txt"
            source.write_text(
                "GOSPEL Example 2.1\nShort reading.\nThe gospel of the Lord.",
                encoding="utf-8",
            )
            fixtures = root / "fixtures.json"
            fixtures.write_text(
                json.dumps(
                    [
                        {
                            "id": "fixture-2",
                            "date": "2026-07-16",
                            "region": "NG",
                            "bibleVersion": "rsvce",
                            "reference": "Example 2:1",
                            "position": "Gospel",
                            "sourceLabel": "unit test source",
                            "sourcePath": "source.txt",
                            "startMarker": "GOSPEL Example 2.1",
                            "contentStartMarker": "Short reading.",
                            "endMarker": "The gospel of the Lord.",
                        }
                    ]
                ),
                encoding="utf-8",
            )
            output = root / "openings.jsonl"

            extractor.write_catalog(fixtures, root, output)

            lines = output.read_text(encoding="utf-8").splitlines()

        self.assertEqual(len(lines), 1)
        self.assertEqual(json.loads(lines[0])["opening200"], "Short reading.")


if __name__ == "__main__":
    unittest.main()
