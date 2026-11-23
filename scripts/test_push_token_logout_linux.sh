#!/usr/bin/env bash
set -euo pipefail

if [[ "${VEDASENTIO_DB_HOST:-}" != "127.0.0.1" ]] ||
   [[ "${VEDASENTIO_DB_NAME:-}" != "vedasentio_push_revoke_ci" ]]; then
    echo "[PUSH-REVOKE-CI] Refusing to use a non-local/non-test database." >&2
    exit 1
fi

export PGPASSWORD="${VEDASENTIO_DB_PASSWORD:?}"
export VEDASENTIO_DATA_ENCRYPTION_KEY_B64="$(openssl rand -base64 32)"
export VEDASENTIO_LOOKUP_HMAC_KEY_B64="$(openssl rand -base64 32)"
export VEDASENTIO_JWT_SIGNING_KEY_B64="$(openssl rand -base64 32)"
export VEDASENTIO_API_TEST_PASSWORD="$(openssl rand -hex 18)"

workdir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/vedasentio-push-revoke-ci.XXXXXX")"
pid=""
log="$workdir/api.log"

cleanup() {
    local code=$?
    trap - EXIT
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
    if ((code != 0)); then
        echo "[PUSH-REVOKE-CI] Failed; sanitized log tail:" >&2
        if [[ -f "$log" ]]; then tail -60 "$log" >&2; fi
    fi
    # Cleanup is only allowed in the disposable, guarded CI database.
    psql -h "$VEDASENTIO_DB_HOST" -p "$VEDASENTIO_DB_PORT" \
      -U "$VEDASENTIO_DB_USER" -d "$VEDASENTIO_DB_NAME" \
      -v ON_ERROR_STOP=1 -c \
      'TRUNCATE TABLE mobile_push_tokens, alarms, sensor_events, user_homes, devices, homes, users RESTART IDENTITY CASCADE;' \
      >/dev/null 2>&1 || true
    rm -rf -- "$workdir"
    exit "$code"
}
trap cleanup EXIT

echo "[PUSH-REVOKE-CI] Migrating isolated PostgreSQL..."
for migration in database/[0-9][0-9][0-9]_*.sql; do
    psql -h "$VEDASENTIO_DB_HOST" -p "$VEDASENTIO_DB_PORT" \
      -U "$VEDASENTIO_DB_USER" -d "$VEDASENTIO_DB_NAME" \
      -v ON_ERROR_STOP=1 -f "$migration" >/dev/null
done

echo "[PUSH-REVOKE-CI] Compiling real API, auth, crypto and PostgreSQL..."
g++ -std=c++20 -O1 -g -Wall -Wextra -pthread \
    -Ibackend/src \
    backend/tools/push_token_logout_api_test.cpp \
    backend/src/api/ApiServer.cpp \
    backend/src/database/Database.cpp \
    backend/src/alarms/AlarmRepository.cpp \
    backend/src/users/UserRepository.cpp \
    backend/src/auth/JwtService.cpp \
    backend/src/auth/PasswordHasher.cpp \
    backend/src/security/CryptoService.cpp \
    -lpqxx -lpq -lsodium -lcpp-httplib \
    -o "$workdir/push_ci"

"$workdir/push_ci" >"$log" 2>&1 &
pid=$!
ready=0
for _ in $(seq 1 150); do
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "[PUSH-REVOKE-CI] Test server exited." >&2
        exit 1
    fi
    if curl -fsS --max-time 2 "http://127.0.0.1:28911/api/health" >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 0.2
done
if ((ready != 1)); then
    echo "[PUSH-REVOKE-CI] Test server unavailable." >&2
    exit 1
fi

python3 scripts/test_push_token_logout_api.py
echo "[PUSH-REVOKE-CI] PASS: HTTP/JWT/PostgreSQL verification completed."
