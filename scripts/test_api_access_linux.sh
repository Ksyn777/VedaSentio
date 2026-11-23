#!/usr/bin/env bash
set -euo pipefail

# Hard guard: this script wipes only the disposable CI database.
if [[ "${VEDASENTIO_DB_HOST:-}" != "127.0.0.1" ]] ||
   [[ "${VEDASENTIO_DB_NAME:-}" != "vedasentio_api_ci" ]]; then
    echo "[API-CI] Refusing a non-local/non-test database." >&2
    exit 1
fi
export PGPASSWORD="${VEDASENTIO_DB_PASSWORD:?}"
export VEDASENTIO_API_TEST_PORT="${VEDASENTIO_API_TEST_PORT:-28900}"
export VEDASENTIO_DATA_ENCRYPTION_KEY_B64="$(openssl rand -base64 32)"
export VEDASENTIO_LOOKUP_HMAC_KEY_B64="$(openssl rand -base64 32)"
export VEDASENTIO_JWT_SIGNING_KEY_B64="$(openssl rand -base64 32)"
export VEDASENTIO_API_TEST_PASSWORD="$(openssl rand -hex 18)"

workdir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/vedasentio-api-ci.XXXXXX")"
pid=""
log="$workdir/api.log"

cleanup() {
    local code=$?
    trap - EXIT
    if ((code != 0)); then
        echo "[API-CI] Failure; sanitized API log tail:" >&2
        if [[ -f "$log" ]]; then
            tail -80 "$log" >&2
        fi
    fi
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
    rm -rf -- "$workdir"
    exit "$code"
}
trap cleanup EXIT

echo "[API-CI] Migrating disposable PostgreSQL database..."
for migration in database/[0-9][0-9][0-9]_*.sql; do
    psql -h "$VEDASENTIO_DB_HOST" -p "$VEDASENTIO_DB_PORT" \
        -U "$VEDASENTIO_DB_USER" -d "$VEDASENTIO_DB_NAME" \
        -v ON_ERROR_STOP=1 -f "$migration" >/dev/null
done

echo "[API-CI] Building production HTTP API, auth, cryptography and persistence..."
g++ -std=c++20 -O1 -g -Wall -Wextra -pthread \
    -Ibackend/src \
    backend/tools/api_access_server_test.cpp \
    backend/src/api/ApiServer.cpp \
    backend/src/database/Database.cpp \
    backend/src/alarms/AlarmRepository.cpp \
    backend/src/users/UserRepository.cpp \
    backend/src/auth/JwtService.cpp \
    backend/src/auth/PasswordHasher.cpp \
    backend/src/security/CryptoService.cpp \
    -lpqxx -lpq -lsodium -lcpp-httplib \
    -o "$workdir/api_ci"

"$workdir/api_ci" >"$log" 2>&1 &
pid=$!
echo "[API-CI] Starting test-only HTTP server on loopback..."
ready=0
for _ in $(seq 1 150); do
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "[API-CI] Server terminated before health check." >&2
        exit 1
    fi
    if curl -fsS --max-time 2 "http://127.0.0.1:$VEDASENTIO_API_TEST_PORT/api/health" >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 0.2
done
if ((ready != 1)); then
    echo "[API-CI] Server unavailable on loopback." >&2
    exit 1
fi

python3 scripts/test_api_access_http.py

# Shut down the throwaway server and clean all fixtures only inside the
# dedicated CI database. Confirm no rows remain.
kill "$pid"
wait "$pid" 2>/dev/null || true
pid=""
psql -h "$VEDASENTIO_DB_HOST" -p "$VEDASENTIO_DB_PORT" \
    -U "$VEDASENTIO_DB_USER" -d "$VEDASENTIO_DB_NAME" \
    -v ON_ERROR_STOP=1 -c \
    "TRUNCATE TABLE mobile_push_tokens, alarms, sensor_events, user_homes,
     devices, homes, users RESTART IDENTITY CASCADE;" >/dev/null

remaining="$(psql -h "$VEDASENTIO_DB_HOST" -p "$VEDASENTIO_DB_PORT" \
    -U "$VEDASENTIO_DB_USER" -d "$VEDASENTIO_DB_NAME" -At \
    -c "SELECT
        (SELECT COUNT(*) FROM users) +
        (SELECT COUNT(*) FROM homes) +
        (SELECT COUNT(*) FROM alarms) +
        (SELECT COUNT(*) FROM sensor_events) +
        (SELECT COUNT(*) FROM mobile_push_tokens);")"

if [[ "$remaining" != "0" ]]; then
    echo "[API-CI] Fixture cleanup failed." >&2
    exit 1
fi
echo "[API-CI] PASS: real HTTP roles, input validation and fixture cleanup."
