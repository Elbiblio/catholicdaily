import importlib.util
import pathlib
import unittest


SCRIPT_PATH = pathlib.Path(__file__).parents[1] / "ensure_ios_push_profile.py"
SPEC = importlib.util.spec_from_file_location("ensure_ios_push_profile", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)


class EnsureIosPushProfileTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        SPEC.loader.exec_module(MODULE)

    def test_normalizes_certificate_serials_for_apple_matching(self):
        self.assertEqual(MODULE.normalize_serial("00:ab:01"), "AB01")
        self.assertEqual(MODULE.normalize_serial("0000"), "0")

    def test_builds_push_capability_payload(self):
        self.assertEqual(
            MODULE.push_capability_payload("bundle-resource-id"),
            {
                "data": {
                    "type": "bundleIdCapabilities",
                    "attributes": {
                        "capabilityType": "PUSH_NOTIFICATIONS",
                        "settings": [],
                    },
                    "relationships": {
                        "bundleId": {
                            "data": {
                                "type": "bundleIds",
                                "id": "bundle-resource-id",
                            }
                        }
                    },
                }
            },
        )

    def test_builds_app_store_profile_for_exact_certificate(self):
        payload = MODULE.profile_payload(
            name="Catholic Daily Push 42",
            bundle_id="bundle-resource-id",
            certificate_id="certificate-resource-id",
        )

        self.assertEqual(payload["data"]["attributes"]["profileType"], "IOS_APP_STORE")
        self.assertEqual(
            payload["data"]["relationships"]["certificates"]["data"],
            [{"type": "certificates", "id": "certificate-resource-id"}],
        )

    def test_selects_only_active_matching_distribution_certificate(self):
        certificates = [
            {
                "id": "wrong-type",
                "attributes": {
                    "serialNumber": "AB01",
                    "certificateType": "DEVELOPMENT",
                    "activated": True,
                },
            },
            {
                "id": "inactive",
                "attributes": {
                    "serialNumber": "AB01",
                    "certificateType": "DISTRIBUTION",
                    "activated": False,
                },
            },
            {
                "id": "match",
                "attributes": {
                    "serialNumber": "00AB01",
                    "certificateType": "IOS_DISTRIBUTION",
                    "activated": True,
                },
            },
        ]

        self.assertEqual(
            MODULE.select_distribution_certificate(certificates, "ab:01")["id"],
            "match",
        )


if __name__ == "__main__":
    unittest.main()
