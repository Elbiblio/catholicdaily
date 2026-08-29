import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "mobile.yml"


class MobileCiWorkflowTest(unittest.TestCase):
    def test_ios_signing_uses_only_the_password_secret(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        ios_job = re.search(r"(?ms)^  ios:\s+.*?(?=^  windows:)", workflow)
        self.assertIsNotNone(ios_job)
        job = ios_job.group(0)
        self.assertIsNotNone(
            re.search(
                r"HAS_IOS_SIGNING: \$\{\{ github\.event_name != 'pull_request' && secrets\.IOS_P12_PASSWORD != '' &&",
                job,
            ),
            "signed iOS flows must require the P12 password secret",
        )
        self.assertTrue(
            "IOS_P12_PASSWORD: ${{ secrets.IOS_P12_PASSWORD }}" in job,
            "the signing step must receive only the P12 password secret",
        )
        candidate_marker = "P12_PASSWORD_" + "CANDIDATES"
        self.assertFalse(candidate_marker in job, "password candidate fallback remains")
        self.assertIsNone(re.search(r"(?m)^\s*P12_PASSWORD\s*=", job))
        self.assertIsNone(re.search(r"(?m)(?:echo|printf)[^\n]*IOS_P12_PASSWORD", job))
        self.assertTrue('if [ -z "$IOS_P12_PASSWORD" ]; then' in job)
        self.assertTrue("-passin env:IOS_P12_PASSWORD" in job)
        self.assertTrue("-passout env:IOS_P12_PASSWORD" in job)
        self.assertTrue('security import "$CERT_PATH" -P "$IOS_P12_PASSWORD"' in job)

    def test_repository_has_no_p12_password_fallback_literals(self):
        tracked = subprocess.check_output(
            ["git", "ls-files", "-z"], cwd=ROOT
        ).decode("utf-8").split("\0")
        offenders = []
        forbidden = (
            re.compile("P12_PASSWORD_" + "CANDIDATES"),
            re.compile(
                r"(?im)^\s*(?:P12|PKCS12)[A-Z0-9_-]*(?:PASSWORD|PASSPHRASE)\s*[:=]\s*['\"](?!\s*$|\$)"
            ),
            re.compile(r"(?i)-(?:passin|passout)\s+pass:(?!\$)"),
        )
        for relative in filter(None, tracked):
            path = ROOT / relative
            try:
                source = path.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            if any(pattern.search(source) for pattern in forbidden):
                offenders.append(relative)
        self.assertEqual([], offenders, "P12 credential fallback patterns found")

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
