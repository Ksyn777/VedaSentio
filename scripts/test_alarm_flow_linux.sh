#!/usr/bin/env bash
set -euo pipefail

required_env=(
  VEDASENTIO_DB_HOST
  VEDASENTIO_DB_PORT
  VEDASENTIO_DB_NAME
  VEDASENTIO_DB_USER
  VEDASENTIO_DB_PASSWORD
)

for name in "${required_env[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "[ALARM-CI] Missing environment variable: $name" >&2
    exit 1
  fi
done

export PGPASSWORD="$VEDASENTIO_DB_PASSWORD"

echo "[ALARM-CI] Applying database migrations..."
for migration in database/[0-9][0-9][0-9]_*.sql; do
  echo "[ALARM-CI] -> $migration"
  psql     --host="$VEDASENTIO_DB_HOST"     --port="$VEDASENTIO_DB_PORT"     --username="$VEDASENTIO_DB_USER"     --dbname="$VEDASENTIO_DB_NAME"     --set=ON_ERROR_STOP=1     --file="$migration"     >/dev/null
done

binary="${RUNNER_TEMP:-/tmp}/vedasentio_alarm_flow_test"

echo "[ALARM-CI] Building focused alarm test with AddressSanitizer and UBSan..."
g++   -std=c++20   -O2   -g   -fno-omit-frame-pointer   -fsanitize=address,undefined   -Wall   -Wextra   -Ibackend/src   backend/tools/alarm_flow_test.cpp   backend/src/database/Database.cpp   backend/src/alarms/AlarmRepository.cpp   -lpqxx   -lpq   -o "$binary"

echo "[ALARM-CI] Running alarm regression test..."
ASAN_OPTIONS=abort_on_error=1:detect_leaks=0:print_stacktrace=1 UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 "$binary"
