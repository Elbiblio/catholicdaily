#!/usr/bin/env python3
"""Enable APNs and create an App Store provisioning profile through Apple's API."""

from __future__ import annotations

import argparse
import base64
import json
import pathlib
import time
import urllib.error
import urllib.parse
import urllib.request


API_ROOT = "https://api.appstoreconnect.apple.com/v1"
DISTRIBUTION_CERTIFICATE_TYPES = {"DISTRIBUTION", "IOS_DISTRIBUTION"}


class AppleApiError(RuntimeError):
    def __init__(self, status: int, body: str):
        super().__init__(f"Apple API returned HTTP {status}: {body}")
        self.status = status
        self.body = body


def normalize_serial(value: str) -> str:
    normalized = "".join(character for character in value.upper() if character in "0123456789ABCDEF")
    return normalized.lstrip("0") or "0"


def push_capability_payload(bundle_id: str) -> dict:
    return {
        "data": {
            "type": "bundleIdCapabilities",
            "attributes": {
                "capabilityType": "PUSH_NOTIFICATIONS",
                "settings": [],
            },
            "relationships": {
                "bundleId": {
                    "data": {"type": "bundleIds", "id": bundle_id}
                }
            },
        }
    }


def profile_payload(*, name: str, bundle_id: str, certificate_id: str) -> dict:
    return {
        "data": {
            "type": "profiles",
            "attributes": {
                "name": name,
                "profileType": "IOS_APP_STORE",
            },
            "relationships": {
                "bundleId": {
                    "data": {"type": "bundleIds", "id": bundle_id}
                },
                "certificates": {
                    "data": [
                        {"type": "certificates", "id": certificate_id}
                    ]
                },
            },
        }
    }


def bundle_capabilities_path(bundle_id: str) -> str:
    # Apple's relationship endpoint rejects the otherwise common `limit` query.
    return f"/bundleIds/{bundle_id}/bundleIdCapabilities"


def select_distribution_certificate(certificates: list[dict], serial: str) -> dict:
    expected = normalize_serial(serial)
    for certificate in certificates:
        attributes = certificate.get("attributes", {})
        if attributes.get("certificateType") not in DISTRIBUTION_CERTIFICATE_TYPES:
            continue
        if attributes.get("activated") is False:
            continue
        if normalize_serial(str(attributes.get("serialNumber", ""))) == expected:
            return certificate
    raise RuntimeError(
        "The imported distribution certificate was not found as an active "
        "certificate in the Apple Developer account."
    )


def make_token(*, issuer_id: str, key_id: str, key_path: pathlib.Path) -> str:
    try:
        import jwt
    except ImportError as error:
        raise RuntimeError("PyJWT and cryptography must be installed") from error

    now = int(time.time())
    return jwt.encode(
        {
            "iss": issuer_id,
            "iat": now,
            "exp": now + 15 * 60,
            "aud": "appstoreconnect-v1",
        },
        key_path.read_text(encoding="utf-8"),
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def api_request(
    token: str,
    method: str,
    path_or_url: str,
    payload: dict | None = None,
) -> dict:
    url = path_or_url if path_or_url.startswith("https://") else f"{API_ROOT}{path_or_url}"
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise AppleApiError(error.code, body) from error


def list_all(token: str, path: str) -> list[dict]:
    resources: list[dict] = []
    next_url: str | None = path
    while next_url:
        response = api_request(token, "GET", next_url)
        resources.extend(response.get("data", []))
        next_url = response.get("links", {}).get("next")
    return resources


def find_bundle_id(token: str, identifier: str) -> dict:
    query = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": 2})
    bundle_ids = list_all(token, f"/bundleIds?{query}")
    exact = [
        bundle_id
        for bundle_id in bundle_ids
        if bundle_id.get("attributes", {}).get("identifier") == identifier
    ]
    if len(exact) != 1:
        raise RuntimeError(
            f"Expected exactly one Apple bundle ID for {identifier}, found {len(exact)}."
        )
    return exact[0]


def ensure_push_capability(token: str, bundle_id: str) -> None:
    path = bundle_capabilities_path(bundle_id)
    capabilities = list_all(token, path)
    if any(
        capability.get("attributes", {}).get("capabilityType") == "PUSH_NOTIFICATIONS"
        for capability in capabilities
    ):
        print("Push Notifications capability is already enabled.")
        return

    try:
        api_request(
            token,
            "POST",
            "/bundleIdCapabilities",
            push_capability_payload(bundle_id),
        )
    except AppleApiError as error:
        if error.status != 409:
            raise
        capabilities = list_all(token, path)
        if not any(
            capability.get("attributes", {}).get("capabilityType") == "PUSH_NOTIFICATIONS"
            for capability in capabilities
        ):
            raise
    print("Push Notifications capability enabled.")


def create_profile(
    token: str,
    *,
    name: str,
    bundle_id: str,
    certificate_id: str,
) -> dict:
    payload = profile_payload(
        name=name,
        bundle_id=bundle_id,
        certificate_id=certificate_id,
    )
    for attempt in range(4):
        try:
            return api_request(token, "POST", "/profiles", payload)["data"]
        except AppleApiError as error:
            if error.status not in {409, 422} or attempt == 3:
                raise
            time.sleep(5 * (attempt + 1))
    raise AssertionError("unreachable")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--key-path", required=True, type=pathlib.Path)
    parser.add_argument("--bundle-identifier", required=True)
    parser.add_argument("--certificate-serial", required=True)
    parser.add_argument("--profile-name", required=True)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    token = make_token(
        issuer_id=args.issuer_id,
        key_id=args.key_id,
        key_path=args.key_path,
    )
    bundle_id = find_bundle_id(token, args.bundle_identifier)
    ensure_push_capability(token, bundle_id["id"])

    certificates = list_all(token, "/certificates?limit=200")
    certificate = select_distribution_certificate(
        certificates,
        args.certificate_serial,
    )
    profile = create_profile(
        token,
        name=args.profile_name,
        bundle_id=bundle_id["id"],
        certificate_id=certificate["id"],
    )
    content = profile.get("attributes", {}).get("profileContent")
    if not content:
        raise RuntimeError("Apple created a profile without profileContent.")
    args.output.write_bytes(base64.b64decode(content, validate=True))
    print(f"Created push-enabled provisioning profile: {profile['attributes']['name']}")


if __name__ == "__main__":
    main()
