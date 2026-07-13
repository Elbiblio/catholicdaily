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

    def test_builds_universalis_entries_from_mass_html(self):
        extractor = load_extractor()

        html = _universalis_sample_html()

        entries = extractor.build_universalis_entries_from_html(
            html=html,
            date="2026-07-15",
            region="NG",
            bible_version="jerusalem",
            source_url="https://universalis.com/africa.nigeria/20260715/mass.htm",
        )

        self.assertEqual([entry["slot"] for entry in entries], ["first", "gospel"])
        self.assertEqual(entries[0]["sourceType"], "universalis_web")
        self.assertEqual(entries[0]["reference"], "Isaiah 10:5-7,13-16")
        self.assertIn("The Lord of hosts says this", entries[0]["opening200"])
        self.assertIn("woe to assyria", entries[0]["normalizedFingerprint"])
        self.assertEqual(entries[1]["reference"], "Matthew 11:25-27")
        self.assertIn("Jesus exclaimed", entries[1]["opening100"])
        self.assertEqual(entries[1]["copyrightMode"], "audit_only")

    def test_writes_universalis_jsonl_output(self):
        extractor = load_extractor()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            html_path = root / "universalis.html"
            html_path.write_text(_universalis_sample_html(), encoding="utf-8")
            output = root / "universalis.jsonl"

            extractor.write_universalis_catalog(
                html_path=html_path,
                date="2026-07-15",
                region="GB_EW",
                bible_version="jerusalem",
                source_url="https://universalis.com/20260715/mass.htm",
                output_path=output,
            )

            lines = output.read_text(encoding="utf-8").splitlines()

        self.assertEqual(len(lines), 2)
        self.assertEqual(json.loads(lines[0])["region"], "GB_EW")

    def test_builds_universalis_urls_for_supported_regions(self):
        extractor = load_extractor()

        self.assertEqual(
            extractor.build_universalis_url("2026-07-15", "GB_EW"),
            "https://universalis.com/20260715/mass.htm",
        )
        self.assertEqual(
            extractor.build_universalis_url("2026-07-15", "NG"),
            "https://universalis.com/africa.nigeria/20260715/mass.htm",
        )

    def test_fetches_universalis_catalog_to_cache(self):
        extractor = load_extractor()
        fetched_urls = []

        def fake_fetch(url):
            fetched_urls.append(url)
            return _universalis_sample_html()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            output = root / "openings.jsonl"
            cache_dir = root / "source-html"

            entries = extractor.write_universalis_fetch_catalog(
                dates=["2026-07-15"],
                region="NG",
                bible_version="jerusalem",
                cache_dir=cache_dir,
                output_path=output,
                fetcher=fake_fetch,
            )

            lines = output.read_text(encoding="utf-8").splitlines()

        self.assertEqual(
            fetched_urls,
            ["https://universalis.com/africa.nigeria/20260715/mass.htm"],
        )
        self.assertEqual(len(entries), 2)
        self.assertEqual(len(lines), 2)
        self.assertEqual(json.loads(lines[0])["date"], "2026-07-15")

    def test_fetch_catalog_fails_when_page_has_no_readings(self):
        extractor = load_extractor()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaisesRegex(ValueError, "No Universalis readings found"):
                extractor.write_universalis_fetch_catalog(
                    dates=["2026-08-15"],
                    region="GB_EW",
                    bible_version="jerusalem",
                    cache_dir=root / "source-html",
                    output_path=root / "openings.jsonl",
                    fetcher=lambda url: "<html><title>Other dates</title></html>",
                )

    def test_parses_single_and_comma_separated_dates(self):
        extractor = load_extractor()

        self.assertEqual(
            extractor.parse_date_args("2026-07-15", "2026-08-15, 2026-10-01"),
            ["2026-07-15", "2026-08-15", "2026-10-01"],
        )


def _universalis_sample_html():
    return """
        <hr class="shortrule"/><table class="each" style="width:100%">
          <tr><th align="left">First reading</th></tr>
          <tr><th align="right">Isaiah 10:5-7,13-16</th></tr>
        </table>
        <h4 style="text-align:center;">Assyria's arrogance</h4>
        <div class="p">The Lord of hosts says this:</div>
        <div class="v gb">Woe to Assyria, the rod of my anger,</div>
        <div class="v">the club brandished by me in my fury!</div>
        <hr class="shortrule"/><table class="each" style="width:100%">
          <tr><th align="left">Responsorial Psalm</th></tr>
          <tr><th align="right">Psalm 93(94):5-10,14-15</th></tr>
        </table>
        <hr class="shortrule"/><table class="each" style="width:100%">
          <tr><th align="left">Gospel Acclamation</th></tr>
          <tr><th align="right">Mt11:25</th></tr>
        </table>
        <div class="v">Alleluia, alleluia!</div>
        <hr class="shortrule"/><table class="each" style="width:100%">
          <tr><th align="left">Gospel</th></tr>
          <tr><th align="right">Matthew 11:25-27</th></tr>
        </table>
        <h4 style="text-align:center;">Hidden from the wise</h4>
        <div class="p">Jesus exclaimed, &#8216;I bless you, Father, Lord of heaven
        and of earth, for hiding these things.&#8217;</div>
        """


if __name__ == "__main__":
    unittest.main()
