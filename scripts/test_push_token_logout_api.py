#!/usr/bin/env python3
"""Real HTTP/JWT/PostgreSQL regression. Uses only synthetic local fixtures."""
import json
import os
import subprocess
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:28911"
PASSWORD = os.environ["VEDASENTIO_API_TEST_PASSWORD"]
CHECKS = 0


def request(method, path, token=None, payload=None, raw=None):
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    if raw is not None:
        data = raw
    elif payload is not None:
        data = json.dumps(payload).encode("utf-8")
    elif method != "GET":
        data = b"{}"
    else:
        data = None
    req = urllib.request.Request(BASE + path, headers=headers, data=data, method=method)
    try:
        with urllib.request.urlopen(req, timeout=7) as response:
            code = response.status
            body = response.read()
    except urllib.error.HTTPError as error:
        code = error.code
        body = error.read()
    return code, json.loads(body) if body else {}


def expect(code, method, path, *, token=None, payload=None, raw=None):
    global CHECKS
    status, body = request(method, path, token, payload, raw)
    assert status == code, f"{method} {path}: expected {code}, got {status}"
    CHECKS += 1
    return body


def login(email):
    data = expect(200, "POST", "/api/auth/login",
                  payload={"email": email, "password": PASSWORD})
    assert data["access_token"]
    return data["access_token"]


def db_state(token):
    # No arbitrary SQL input: all tokens used below are hardcoded CI identifiers.
    assert token in ("ci-device-one", "ci-device-two")
    sql = ("SELECT u.id::text || ':' || m.is_active::text "
           "FROM mobile_push_tokens m JOIN users u ON u.id=m.user_id "
           f"WHERE m.fcm_token='{token}'")
    args = [
        "psql", "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1",
        "-h", os.environ["VEDASENTIO_DB_HOST"],
        "-p", os.environ["VEDASENTIO_DB_PORT"],
        "-U", os.environ["VEDASENTIO_DB_USER"],
        "-d", os.environ["VEDASENTIO_DB_NAME"], "-c", sql,
    ]
    proc = subprocess.run(args, check=True, capture_output=True, text=True)
    return proc.stdout.strip()


def main():
    owner_a = login("push-owner-a@example.invalid")
    owner_b = login("push-owner-b@example.invalid")
    route = "/api/mobile-devices/push-token"

    # Registration with a real bearer token, then lookup in actual PostgreSQL.
    expect(200, "POST", route, token=owner_a,
           payload={"fcm_token": "ci-device-one", "platform": "android"})
    expect(200, "POST", route, token=owner_b,
           payload={"fcm_token": "ci-device-two", "platform": "ios"})
    initial_one = db_state("ci-device-one")
    initial_two = db_state("ci-device-two")
    assert initial_one.endswith(":true") and initial_two.endswith(":true")
    assert initial_one != initial_two

    # Both missing and bad JWT must be 401 and leave token active.
    expect(401, "DELETE", route, payload={"fcm_token": "ci-device-one"})
    expect(401, "DELETE", route, token="not.a.jwt",
           payload={"fcm_token": "ci-device-one"})
    assert db_state("ci-device-one") == initial_one

    # Ownership is enforced in SQL. A foreign token cannot be revoked or
    # transferred by the DELETE endpoint, nor can its existence be probed.
    assert expect(200, "DELETE", route, token=owner_b,
                  payload={"fcm_token": "ci-device-one"})["status"] == "unregistered"
    assert db_state("ci-device-one") == initial_one

    assert expect(200, "DELETE", route, token=owner_a,
                  payload={"fcm_token": "ci-device-one"})["status"] == "unregistered"
    assert db_state("ci-device-one") == initial_one.replace(":true", ":false")
    assert db_state("ci-device-two") == initial_two

    # Idempotence and absent tokens reveal no ownership details.
    expect(200, "DELETE", route, token=owner_a,
           payload={"fcm_token": "ci-device-one"})
    expect(200, "DELETE", route, token=owner_a,
           payload={"fcm_token": "not-found-ci"})
    assert db_state("ci-device-one").endswith(":false")

    # Validation never touches a token row.
    expect(400, "DELETE", route, token=owner_a, payload={})
    expect(400, "DELETE", route, token=owner_a, payload={"fcm_token": ""})
    expect(400, "DELETE", route, token=owner_a, payload={"fcm_token": 7})
    expect(400, "DELETE", route, token=owner_a, raw=b'not-json')
    expect(400, "DELETE", route, token=owner_a, raw=b'[]')
    expect(400, "DELETE", route, token=owner_a,
           payload={"fcm_token": "A" * 8193})
    expect(413, "DELETE", route, token=owner_a,
           payload={"fcm_token": "A" * 16400})
    assert db_state("ci-device-two") == initial_two

    # Shared phone switches accounts: UPSERT reassigns a unique token.
    expect(200, "POST", route, token=owner_b,
           payload={"fcm_token": "ci-device-one", "platform": "android"})
    transferred = db_state("ci-device-one")
    assert transferred.endswith(":true") and transferred != initial_one

    # Former owner cannot revoke the new owner's device token.
    expect(200, "DELETE", route, token=owner_a,
           payload={"fcm_token": "ci-device-one"})
    assert db_state("ci-device-one") == transferred

    expect(200, "DELETE", route, token=owner_b,
           payload={"fcm_token": "ci-device-one"})
    expect(200, "DELETE", route, token=owner_b,
           payload={"fcm_token": "ci-device-two"})
    assert db_state("ci-device-one").endswith(":false")
    assert db_state("ci-device-two").endswith(":false")

    print(f"[PUSH-REVOKE-CI] PASS: {CHECKS} HTTP checks; DB owner scoping, "
          "idempotence, account transfer and inactive token rows.")


if __name__ == "__main__":
    main()
