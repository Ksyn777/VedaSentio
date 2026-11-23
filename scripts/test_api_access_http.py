#!/usr/bin/env python3
"""HTTP regression against the real API server and an isolated PostgreSQL DB.

No production URLs, emails, passwords, tokens or real device identifiers.
"""
import json
import os
import base64
import hashlib
import hmac
import time
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:" + os.environ["VEDASENTIO_API_TEST_PORT"]
PASSWORD = os.environ["VEDASENTIO_API_TEST_PASSWORD"]
checks = 0


def call(method, path, token=None, payload=None, cache_required=True):
    data = None
    if payload is not None:
        data = payload if isinstance(payload, bytes) else json.dumps(payload).encode("utf-8")
    elif method == "POST":
        data = b"{}"
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if token is not None:
        headers["Authorization"] = "Bearer " + token

    request = urllib.request.Request(
        BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            code = response.status
            raw = response.read()
            result_headers = dict(response.headers.items())
    except urllib.error.HTTPError as error:
        code = error.code
        raw = error.read()
        result_headers = dict(error.headers.items())
    body = json.loads(raw) if raw and cache_required else None
    if cache_required:
        assert result_headers.get("Cache-Control") == "no-store", (
            "Missing cache security header: " + path)
    return code, body, result_headers


def expect(code, method, path, *, token=None, payload=None, cache_required=True):
    global checks
    actual, body, headers = call(method, path, token, payload, cache_required)
    assert actual == code, (
        f"Expected {code}, got {actual}: {method} {path}")
    checks += 1
    return body


def login(email):
    body = expect(200, "POST", "/api/auth/login",
                  payload={"email": email, "password": PASSWORD})
    assert body["token_type"] == "Bearer"
    assert isinstance(body["access_token"], str)
    assert body["expires_in"] > 0
    return body["access_token"]


def expired_token(token):
    """Sign an expired fixture token with this disposable run's random key."""
    header, payload, _ = token.split(".")
    claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
    claims["iat"] = int(time.time()) - 7200
    claims["exp"] = int(time.time()) - 3600
    encoded = base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
    signing_input = header + "." + encoded
    key = base64.b64decode(os.environ["VEDASENTIO_JWT_SIGNING_KEY_B64"])
    signature = hmac.new(key, signing_input.encode(), hashlib.sha256).digest()
    return signing_input + "." + base64.urlsafe_b64encode(signature).rstrip(b"=").decode()


def main():
    expect(200, "GET", "/api/health")
    missing = expect(401, "GET", "/api/me")
    assert "error" in missing
    expect(401, "GET", "/api/homes/api_home_ci/devices")
    expect(401, "GET", "/api/homes")
    expect(401, "POST", "/api/homes/api_home_ci/alarms/1/acknowledge")

    owner = login("api-owner@example.invalid")
    caregiver = login("api-caregiver@example.invalid")
    viewer = login("api-viewer@example.invalid")
    outsider = login("api-outsider@example.invalid")

    for suffix in ("/events", "/devices/sos_one/latest", "/alarms"):
        expect(401, "GET", "/api/homes/api_home_ci" + suffix)
    for method, path in (
        ("GET", "/api/homes/api_home_ci/devices"),
        ("GET", "/api/homes/api_home_ci/events"),
        ("GET", "/api/homes/api_home_ci/devices/sos_one/latest"),
        ("GET", "/api/homes/api_home_ci/alarms"),
        ("POST", "/api/homes/api_home_ci/alarms/1/acknowledge"),
        ("POST", "/api/mobile-devices/push-token"),
    ):
        expect(401, method, path, token="not.a.jwt")
    expired = expired_token(owner)
    expect(401, "GET", "/api/me", token=expired)
    expect(401, "POST", "/api/homes/api_home_ci/alarms/1/acknowledge", token=expired)
    for invalid_body in (b"not-json", [], {"email": 1, "password": "test"}):
        expect(400, "POST", "/api/auth/login", payload=invalid_body)

    expect(401, "GET", "/api/me", token=owner + "tampered")
    expect(401, "GET", "/api/homes", token="not.a.jwt")
    wrong = expect(401, "POST", "/api/auth/login", payload={
        "email": "api-owner@example.invalid", "password": "WRONG-CI-ONLY"})
    assert "error" in wrong
    expect(400, "POST", "/api/auth/login", payload={"email": "missing-password"})
    # A valid JSON request beyond the login size limit must be refused.
    huge = {"email": "api-owner@example.invalid", "password": "A" * 8200}
    expect(413, "POST", "/api/auth/login", payload=huge)

    me = expect(200, "GET", "/api/me", token=owner)
    assert me["email"] == "api-owner@example.invalid"
    assert {x["home_id"] for x in me["homes"]} == {"api_home_ci"}

    own_homes = expect(200, "GET", "/api/homes", token=owner)
    other_homes = expect(200, "GET", "/api/homes", token=outsider)
    assert [x["id"] for x in own_homes] == ["api_home_ci"]
    assert [x["id"] for x in other_homes] == ["api_other_ci"]

    devices = expect(200, "GET", "/api/homes/api_home_ci/devices", token=viewer)
    assert {x["id"] for x in devices} == {"sos_one", "sos_two"}
    events = expect(200, "GET", "/api/homes/api_home_ci/events", token=owner)
    assert len(events) == 2
    assert all(x["event_type"] == "sos_pressed" for x in events)
    expect(200, "GET", "/api/homes/api_home_ci/devices/sos_one/latest", token=owner)
    expect(404, "GET", "/api/homes/api_home_ci/devices/unknown/latest", token=owner)

    # Home separation must apply on every resource route, including writes.
    for suffix in (
        "/devices", "/events", "/devices/sos_one/latest", "/alarms"
    ):
        expect(403, "GET", "/api/homes/api_home_ci" + suffix, token=outsider)
    expect(403, "POST", "/api/homes/api_home_ci/alarms/1/acknowledge",
           token=outsider)
    expect(403, "GET", "/api/homes/api_other_ci/events", token=owner)

    for route in ("events", "alarms"):
        base = f"/api/homes/api_home_ci/{route}"
        limited = expect(200, "GET", base + "?limit=1", token=owner)
        assert len(limited) == 1
        bounded = expect(200, "GET", base + "?limit=10000", token=owner)
        assert len(bounded) == (2 if route == "events" else 3)
        for raw in ("0", "-1", "3abc", "1.5", "", "%20", "%2B1", "9999999999999999999999999999"):
            expect(400, "GET", base + "?limit=" + raw, token=owner)

    for active in ("invalid", "TRUE", "2"):
        expect(400, "GET", "/api/homes/api_home_ci/alarms?active=" + active,
               token=owner)
    active = expect(200, "GET", "/api/homes/api_home_ci/alarms?active=true",
                    token=viewer)
    assert len(active) == 2
    alarms_by_device = {a["device_id"]: a for a in active}
    a_id = alarms_by_device["sos_one"]["id"]
    b_id = alarms_by_device["sos_two"]["id"]

    expect(403, "POST",
           f"/api/homes/api_home_ci/alarms/{a_id}/acknowledge", token=viewer)
    # Overflow/zero alarm IDs must not crash the backend or produce 500.
    expect(400, "POST", "/api/homes/api_home_ci/alarms/0/acknowledge",
           token=owner)
    expect(400, "POST", "/api/homes/api_home_ci/alarms/99999999999999999999999999/acknowledge",
           token=owner)
    expect(404, "POST", "/api/homes/api_home_ci/alarms/9999999/acknowledge",
           token=owner)

    acknowledged = expect(
        200, "POST", f"/api/homes/api_home_ci/alarms/{a_id}/acknowledge",
        token=caregiver)
    assert acknowledged["id"] == a_id
    assert acknowledged["status"] == "acknowledged"
    assert acknowledged["acknowledged_by"] is not None
    acknowledged_owner = expect(
        200, "POST", f"/api/homes/api_home_ci/alarms/{b_id}/acknowledge",
        token=owner)
    assert acknowledged_owner["id"] == b_id
    assert acknowledged_owner["status"] == "acknowledged"

    for raw_id in ("-1", "abc", "12abc"):
        # These paths do not match the numeric-ID route: httplib returns its
        # default 404, outside send_json and its no-store response headers.
        expect(404, "POST", f"/api/homes/api_home_ci/alarms/{raw_id}/acknowledge",
               token=owner, cache_required=False)
    expect(403, "POST", f"/api/homes/api_other_ci/alarms/{a_id}/acknowledge", token=owner)
    for role_token in (owner, caregiver, viewer):
        history = expect(200, "GET", "/api/homes/api_home_ci/alarms?active=false", token=role_token)
        assert len(history) == 3
        assert {a["id"] for a in history if a["status"] == "acknowledged"} == {a_id, b_id}
        assert len([a for a in history if a["status"] == "resolved"]) == 1
    # Repeating an authorized acknowledgement must preserve the first actor.
    repeated = expect(200, "POST", f"/api/homes/api_home_ci/alarms/{a_id}/acknowledge", token=owner)
    assert repeated["acknowledged_by"] == acknowledged["acknowledged_by"]

    # Registered mobile token is synthetic and never delivered to Firebase.
    expect(401, "POST", "/api/mobile-devices/push-token")
    expect(400, "POST", "/api/mobile-devices/push-token",
           token=owner, payload={"fcm_token": "fake-ci-token", "platform": "windows"})
    saved = expect(200, "POST", "/api/mobile-devices/push-token",
                   token=owner,
                   payload={"fcm_token": "ci-synthetic-not-a-real-fcm-token",
                            "platform": "android"})
    assert saved["status"] == "registered"

    for invalid_body in (
        b"not-json", [], {"fcm_token": 123, "platform": "android"},
        {"fcm_token": "", "platform": "android"},
        {"fcm_token": "synthetic", "platform": 123},
        {"fcm_token": "synthetic"},
        {"fcm_token": "x" * 8193, "platform": "android"},
    ):
        expect(400, "POST", "/api/mobile-devices/push-token", token=owner, payload=invalid_body)
    expect(413, "POST", "/api/mobile-devices/push-token", token=owner,
           payload={"fcm_token": "x" * 17000, "platform": "android"})

    expect(200, "GET", "/api/health")
    print(f"[API-CI] PASS: {checks} HTTP access, query validation and alarm cases.")


if __name__ == "__main__":
    main()
