import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "mobile.yml"


class MobileCiWorkflowTest(unittest.TestCase):
    def test_windows_release_uses_flutter_compatible_runner(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        match = re.search(
            r"(?ms)^  windows:\s+.*?^    runs-on:\s*([^\s#]+)",
            workflow,
        )

        self.assertIsNotNone(match, "Windows release job was not found")
        self.assertEqual("windows-2022", match.group(1))


if __name__ == "__main__":
    unittest.main()
