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

    def test_ios_pull_requests_always_build_without_codesign(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        ios_job = re.search(r"(?ms)^  ios:\s+.*?(?=^  windows:)", workflow)
        self.assertIsNotNone(ios_job)
        job = ios_job.group(0)
        self.assertRegex(
            job,
            r"HAS_IOS_SIGNING: \$\{\{ github\.event_name != 'pull_request' &&",
        )
        self.assertRegex(
            job,
            r"HAS_R2_ACCESS: \$\{\{ github\.event_name != 'pull_request' &&",
        )
        self.assertIn(
            "if: github.event_name == 'pull_request' || env.HAS_IOS_SIGNING != 'true'",
            job,
        )

    def test_ios_pull_requests_cannot_prepare_signing_or_upload_testflight(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        ios_job = re.search(r"(?ms)^  ios:\s+.*?(?=^  windows:)", workflow)
        self.assertIsNotNone(ios_job)
        job = ios_job.group(0)
        self.assertRegex(
            job,
            r"HAS_TESTFLIGHT_UPLOAD: \$\{\{ github\.event_name != 'pull_request' &&",
        )
        for step_name in (
            "Prepare signing assets",
            "Generate export options",
            "Inject build settings into Release xcconfig",
            "Build signed iOS IPA",
            "Package signed iOS artifacts",
            "Prepare App Store Connect API key",
            "Upload to TestFlight",
        ):
            step = re.search(
                rf"(?ms)^      - name: {re.escape(step_name)}\s+.*?(?=^      - name:|^  windows:)",
                job,
            )
            self.assertIsNotNone(step, step_name)
            self.assertIn("github.event_name != 'pull_request'", step.group(0))


if __name__ == "__main__":
    unittest.main()
