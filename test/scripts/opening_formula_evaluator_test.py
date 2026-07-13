import importlib.util
import tempfile
import unittest
from pathlib import Path


def load_evaluator():
    repo_root = Path(__file__).resolve().parents[2]
    script = repo_root / "scripts" / "active" / "evaluate_opening_formula.py"
    spec = importlib.util.spec_from_file_location("evaluate_opening_formula", script)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class OpeningFormulaEvaluatorTest(unittest.TestCase):
    def test_surgical_formula_accepts_unique_early_anchor(self):
        evaluator = load_evaluator()

        result = evaluator.evaluate_pair(
            source_opening=(
                "At that time Jesus said to his disciples, "
                "Love one another as I have loved you. "
                "No one has greater love than this."
            ),
            rendered_text=(
                "12 Love one another as I have loved you. "
                "No one has greater love than this. "
                "You are my friends if you do what I command you."
            ),
        )

        self.assertEqual(result["decision"], "surgical_replace")
        self.assertGreaterEqual(result["anchorCharacters"], 50)

    def test_surgical_formula_rejects_short_opening(self):
        evaluator = load_evaluator()

        result = evaluator.evaluate_pair(
            source_opening="Jesus said to his disciples.",
            rendered_text="Jesus said to his disciples, Be watchful and ready.",
        )

        self.assertEqual(result["decision"], "catalog_only_short_opening")

    def test_surgical_formula_rejects_translation_mismatch(self):
        evaluator = load_evaluator()

        result = evaluator.evaluate_pair(
            source_opening=(
                "At that time Jesus said, I thank you, Father, Lord of heaven "
                "and earth, because you have revealed these things to infants."
            ),
            rendered_text=(
                "25 At that time Jesus declared, I thank thee, Father, Lord of "
                "heaven and earth, that thou hast hidden these things from the wise."
            ),
        )

        self.assertEqual(result["decision"], "no_surgical_anchor")

    def test_fetches_db_text_for_simple_reference(self):
        evaluator = load_evaluator()

        with tempfile.TemporaryDirectory() as tmp:
            db_path = Path(tmp) / "bible.db"
            evaluator.create_test_bible_db(db_path)

            text = evaluator.fetch_db_text(db_path, "Isaiah 2.1-2")

        self.assertIn("The word which Isaiah", text)
        self.assertIn("all the nations shall flow to it", text)


if __name__ == "__main__":
    unittest.main()
