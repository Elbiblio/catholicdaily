import csv
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import shutil

from scripts.build_lectionary_catalog_v3 import extract_entries
from scripts import restore_lectionary_canticles

ROOT = Path(__file__).resolve().parents[2]


class LectionaryPsalmCompletenessTest(unittest.TestCase):
    def test_canticles_are_extracted_with_their_response(self):
        source = ('THIRD WEEK IN ORDINARY TIME\n'
                  '322 SATURDAY\n'
                  'RESPONSORIAL CANTICLE Luke 1.69-70, 71-72, 73-75 (R. 68)\n'
                  'R. Blessed be the Lord, the God of Israel,\n'
                  'who has come to his people.\n'
                  '69 He has raised up a mighty saviour.\n')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'source.txt'
            path.write_text(source, encoding='utf-8')
            rows = extract_entries(path)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['psalm_reference'], 'Luke 1.69-70, 71-72, 73-75 (R. 68)')
        self.assertEqual(rows[0]['response_text'],
                         'Blessed be the Lord, the God of Israel, who has come to his people.')

    def test_every_standard_mass_has_a_psalm_or_canticle_and_response(self):
        with (ROOT / 'standard_lectionary_complete.csv').open(encoding='utf-8-sig', newline='') as handle:
            missing = [(index, row['first_reading']) for index, row in enumerate(csv.DictReader(handle), 2)
                       if not row['psalm_reference'].strip() or not row['psalm_response'].strip()]
        self.assertEqual(missing, [])

    def test_december_22_restoration_fixes_text_and_date_in_one_idempotent_run(self):
        with (ROOT / 'standard_lectionary_complete.csv').open(encoding='utf-8-sig', newline='') as handle:
            reader = csv.DictReader(handle)
            fields = reader.fieldnames
            row = next(row for row in reader if row['day'] == 'December 22')
        row.update(psalm_reference='', psalm_response='', week='3')
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            (fixture / 'scripts').mkdir()
            shutil.copyfile(ROOT / 'scripts/weekday_a_full.txt', fixture / 'scripts/weekday_a_full.txt')
            target = fixture / 'standard_lectionary_complete.csv'
            with target.open('w', encoding='utf-8', newline='') as handle:
                writer = csv.DictWriter(handle, fieldnames=fields)
                writer.writeheader()
                writer.writerow(row)
            with patch.object(restore_lectionary_canticles, 'ROOT', fixture):
                self.assertEqual(restore_lectionary_canticles.restore(), 1)
                first = target.read_bytes()
                with target.open(encoding='utf-8', newline='') as handle:
                    restored = next(csv.DictReader(handle))
                self.assertEqual(restored['week'], 'Dec 17-24')
                self.assertTrue(restored['psalm_reference'].startswith('1 Samuel 2.1'))
                self.assertEqual(restore_lectionary_canticles.restore(), 0)
                self.assertEqual(target.read_bytes(), first)


if __name__ == '__main__':
    unittest.main()
