#!/usr/bin/env python3
"""Fixture and static project validation for the iOS reminder service extension."""

from __future__ import annotations

import datetime as dt
import json
import plistlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tool" / "fixtures" / "ios_notification_service_payloads.json"
SWIFT = ROOT / "ios" / "FeastReminderNotificationService" / "NotificationService.swift"
PLIST = ROOT / "ios" / "FeastReminderNotificationService" / "Info.plist"
PBXPROJ = ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj"
WORKFLOW = ROOT / ".github" / "workflows" / "mobile.yml"
EXTENSION_DEBUG_XCCONFIG = ROOT / "ios" / "Flutter" / "FeastReminderNotificationServiceDebug.xcconfig"
EXTENSION_RELEASE_XCCONFIG = ROOT / "ios" / "Flutter" / "FeastReminderNotificationServiceRelease.xcconfig"


def _integer(value: object) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, str) and re.fullmatch(r"[0-9]+", value):
        return int(value)
    return None


def stable_notification_id(value: str) -> int:
    value_hash = 0x811C9DC5
    for byte in value.encode("utf-8"):
        value_hash ^= byte
        value_hash = (value_hash * 0x01000193) & 0xFFFFFFFF
    positive = value_hash & 0x7FFFFFFF
    return positive or 1


def _instant(value: object) -> dt.datetime | None:
    if not isinstance(value, str):
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def request_identifier(payload: dict[str, object], now: dt.datetime) -> str | None:
    aps = payload.get("aps")
    if not isinstance(aps, dict) or _integer(aps.get("mutable-content")) != 1:
        return None
    if _integer(payload.get("schema")) != 3:
        return None
    if payload.get("type") != "feast_reminder":
        return None

    key = payload.get("occurrence_key")
    if not isinstance(key, str):
        return None
    match = re.fullmatch(
        r"feast:([a-z0-9]+(?:-[a-z0-9]+)*):(\d{4}-\d{2}-\d{2}):(eve|on_day):([a-z0-9]+(?:-[a-z0-9]+)*)",
        key,
    )
    if match is None:
        return None
    region, date, timing, celebration_id = match.groups()
    try:
        dt.datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        return None
    payload_region = payload.get("liturgical_region")
    if not isinstance(payload_region, str) or _slug(payload_region) != region:
        return None
    if payload.get("celebration_date") != date:
        return None
    if payload.get("timing") != timing:
        return None
    saint_id = payload.get("saint_id")
    if saint_id is not None and (
        not isinstance(saint_id, str) or _slug(saint_id) != celebration_id
    ):
        return None

    notification_id = _integer(payload.get("local_notification_id"))
    if notification_id is None or notification_id != stable_notification_id(key):
        return None
    scheduled = _instant(payload.get("scheduled_for"))
    expiry = _instant(payload.get("remote_expires_at"))
    safety = _instant(payload.get("local_safety_at"))
    if scheduled is None or expiry is None or safety is None or expiry <= now:
        return None
    if expiry - scheduled != dt.timedelta(minutes=2):
        return None
    if safety - scheduled != dt.timedelta(minutes=3):
        return None
    return str(notification_id)


def _slug(value: str) -> str:
    return re.sub(r"^-+|-+$", "", re.sub(r"[^a-z0-9]+", "-", value.strip().lower())) or "celebration"


class CancellationGateModel:
    def __init__(self) -> None:
        self.state = "awaiting_cancellation_decision"
        self.actions: list[str] = []

    def event(self, name: str) -> None:
        if name == "begin_cancellation" and self.state == "awaiting_cancellation_decision":
            self.state = "cancellation_started"
            self.actions.append("cancel")
        elif name == "complete_cancellation" and self.state == "cancellation_started":
            self.state = "finished"
            self.actions.append("handler_valid")
        elif name == "timeout" and self.state in {
            "awaiting_cancellation_decision",
            "cancellation_started",
        }:
            self.state = "finished"
            self.actions.append("handler_original")
        elif name == "complete_without_cancellation" and self.state == "awaiting_cancellation_decision":
            self.state = "finished"
            self.actions.append("handler_original")


class IosNotificationServiceValidation(unittest.TestCase):
    def test_payload_fixtures(self) -> None:
        document = json.loads(FIXTURES.read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(document["cases"]), 6)
        for case in document["cases"]:
            with self.subTest(case=case["name"]):
                now = _instant(case["now"])
                self.assertIsNotNone(now)
                self.assertEqual(
                    case["expected_identifier"],
                    request_identifier(case["payload"], now),
                )

    def test_cancellation_gate_race_fixtures(self) -> None:
        document = json.loads(FIXTURES.read_text(encoding="utf-8"))
        for case in document["race_cases"]:
            with self.subTest(case=case["name"]):
                gate = CancellationGateModel()
                for event in case["events"]:
                    gate.event(event)
                self.assertEqual(case["expected_actions"], gate.actions)
                self.assertEqual(case["expected_state"], gate.state)

    def test_swift_implements_contract_and_atomic_cancellation_gate(self) -> None:
        source = SWIFT.read_text(encoding="utf-8")
        for token in (
            '"schema"',
            '"type"',
            '"feast_reminder"',
            '"occurrence_key"',
            '"local_notification_id"',
            '"remote_expires_at"',
            '"mutable-content"',
            "stableNotificationIdentifier",
            "isValidCelebrationDate",
            "removePendingNotificationRequests(withIdentifiers:",
            "serviceExtensionTimeWillExpire",
            "NSLock",
            "awaitingCancellationDecision",
            "cancellationStarted",
            "beginCancellation",
            "completeAfterCancellation",
            "completeWithoutCancellation",
            "completeForTimeout",
        ):
            self.assertIn(token, source)
        self.assertEqual(1, source.count("handler(content)"))
        self.assertEqual(1, source.count("removePendingNotificationRequests(withIdentifiers:"))
        identity_start = source.index("private static func validIdentity")
        identity_guard = source.index("guard\n", identity_start)
        identity_else = source.index("else {", identity_guard)
        self.assertIn(
            'let region = nonEmptyString(userInfo["liturgical_region"]),',
            source[identity_guard:identity_else],
        )
        remove_index = source.index("removePendingNotificationRequests(withIdentifiers:")
        begin_index = source.rindex("beginCancellation", 0, remove_index)
        complete_index = source.index("completeAfterCancellation", remove_index)
        self.assertLess(begin_index, remove_index)
        self.assertLess(remove_index, complete_index)
        timeout_start = source.index("private func completeForTimeout")
        timeout_end = source.index("private func finish", timeout_start)
        timeout_source = source[timeout_start:timeout_end]
        self.assertIn(".awaitingCancellationDecision", timeout_source)
        self.assertIn(".cancellationStarted", timeout_source)

    def test_extension_plist_declares_notification_service(self) -> None:
        with PLIST.open("rb") as stream:
            document = plistlib.load(stream)
        extension = document["NSExtension"]
        self.assertEqual(
            "com.apple.usernotifications.service",
            extension["NSExtensionPointIdentifier"],
        )
        self.assertEqual("$(PRODUCT_MODULE_NAME).NotificationService", extension["NSExtensionPrincipalClass"])
        self.assertEqual("$(MARKETING_VERSION)", document["CFBundleShortVersionString"])
        self.assertEqual("$(CURRENT_PROJECT_VERSION)", document["CFBundleVersion"])

    def test_extension_build_configs_resolve_flutter_versions(self) -> None:
        project = PBXPROJ.read_text(encoding="utf-8")
        self.assertRegex(
            project,
            r"(?s)FE45A0000000000000000016 /\* Debug \*/ = \{.*?baseConfigurationReference = [A-F0-9]{24} /\* FeastReminderNotificationServiceDebug\.xcconfig \*/;",
        )
        for config_id in (
            "FE45A0000000000000000016",
            "FE45A0000000000000000017",
            "FE45A0000000000000000018",
        ):
            block = re.search(rf"(?s){config_id} /\* .*? \*/ = \{{(.*?)\n\t\t\}};", project)
            self.assertIsNotNone(block)
            self.assertIn('CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";', block.group(1))
            self.assertIn('MARKETING_VERSION = "$(FLUTTER_BUILD_NAME)";', block.group(1))
        for config_id, name in (
            ("FE45A0000000000000000017", "Release"),
            ("FE45A0000000000000000018", "Profile"),
        ):
            self.assertRegex(
                project,
                rf"(?s){config_id} /\* {name} \*/ = \{{.*?baseConfigurationReference = [A-F0-9]{{24}} /\* FeastReminderNotificationServiceRelease\.xcconfig \*/;",
            )
        for path in (EXTENSION_DEBUG_XCCONFIG, EXTENSION_RELEASE_XCCONFIG):
            source = path.read_text(encoding="utf-8")
            self.assertIn('#include "Generated.xcconfig"', source)
            self.assertNotIn("Pods-Runner", source)
        generated = (ROOT / "ios" / "Flutter" / "Generated.xcconfig").read_text(encoding="utf-8")
        values = dict(
            line.split("=", 1)
            for line in generated.splitlines()
            if "=" in line and not line.lstrip().startswith("//")
        )
        self.assertTrue(values.get("FLUTTER_BUILD_NAME", "").strip())
        self.assertTrue(values.get("FLUTTER_BUILD_NUMBER", "").strip())

    def test_xcode_project_builds_and_embeds_ios15_extension(self) -> None:
        project = PBXPROJ.read_text(encoding="utf-8")
        for token in (
            "FeastReminderNotificationService.appex in Embed App Extensions",
            'dstSubfolderSpec = 13;',
            'productType = "com.apple.product-type.app-extension";',
            "NotificationService.swift in Sources",
            "UserNotifications.framework in Frameworks",
            "target = FE45A0000000000000000001",
            "IPHONEOS_DEPLOYMENT_TARGET = 15.0;",
            "PRODUCT_BUNDLE_IDENTIFIER = com.elbiblio.catholicdaily.FeastReminderNotificationService;",
        ):
            self.assertIn(token, project)
        runner_match = re.search(
            r"97C146ED1CF9000F007C117D /\* Runner \*/ = \{.*?buildPhases = \((.*?)\);.*?dependencies = \((.*?)\);",
            project,
            re.DOTALL,
        )
        self.assertIsNotNone(runner_match)
        self.assertIn("Embed App Extensions", runner_match.group(1))
        self.assertIn("FeastReminderNotificationService", runner_match.group(2))

    def test_mobile_ci_validates_built_appex_and_signing(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        for token in (
            "IOS_EXTENSION_PROVISION_PROFILE",
            "FeastReminderNotificationService.appex",
            "embedded.mobileprovision",
            "codesign -d --entitlements",
            "RUNNER_ENTITLEMENTS",
            "RUNNER_SIGNED_APP_ID",
            "RUNNER_PROFILE_APP_ID",
            "RUNNER_PROFILE_TEAM",
            "TeamIdentifier.0",
            "IOS_APP_IDENTIFIER_PREFIX",
            "IOS_BUNDLE_ID",
            "aps-environment",
            "CFBundleIdentifier",
            "NSExtensionPointIdentifier",
            "python3 -m unittest discover -s test/scripts -p 'mobile_ci_workflow_test.py'",
        ):
            self.assertIn(token, workflow)
        ios_job = re.search(r"(?ms)^  ios:\s+.*?(?=^  windows:)", workflow)
        self.assertIsNotNone(ios_job)
        self.assertIn("github.event_name == 'pull_request'", ios_job.group(0))
        self.assertRegex(
            ios_job.group(0),
            r"HAS_IOS_SIGNING: \$\{\{ github\.event_name != 'pull_request' &&",
        )
        self.assertRegex(
            ios_job.group(0),
            r"HAS_TESTFLIGHT_UPLOAD: \$\{\{ github\.event_name != 'pull_request' &&",
        )
        self.assertIn(
            "if: github.event_name == 'pull_request' || env.HAS_IOS_SIGNING != 'true'",
            ios_job.group(0),
        )
        for assertion in (
            'EXPECTED_RUNNER_APP_ID="${IOS_APP_IDENTIFIER_PREFIX}.${{ env.IOS_BUNDLE_ID }}"',
            'test "$RUNNER_BUNDLE_ID" = "${{ env.IOS_BUNDLE_ID }}"',
            'test "$RUNNER_SIGNED_APP_ID" = "$EXPECTED_RUNNER_APP_ID"',
            'test "$RUNNER_PROFILE_APP_ID" = "$EXPECTED_RUNNER_APP_ID"',
            'test "$RUNNER_PROFILE_TEAM" = "${{ env.APPLE_TEAM_ID }}"',
            'test "$EXTENSION_SIGNED_APP_ID" = "$EXPECTED_EXTENSION_APP_ID"',
            'test "$EXTENSION_PROFILE_APP_ID" = "$EXPECTED_EXTENSION_APP_ID"',
            'test "$EXTENSION_PROFILE_TEAM" = "${{ env.APPLE_TEAM_ID }}"',
        ):
            self.assertIn(assertion, ios_job.group(0))


if __name__ == "__main__":
    unittest.main(verbosity=2)
