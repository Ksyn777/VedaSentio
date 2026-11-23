#!/usr/bin/env bash
set -euo pipefail

# Dedicated ephemeral PostgreSQL and local broker. Never use against production.
if [[ "${VEDASENTIO_DB_HOST:-}" != "127.0.0.1" ]] ||
   [[ "${VEDASENTIO_DB_NAME:-}" != "vedasentio_alarm_ci" ]]; then
    echo "[ALARM-MQTT] Refusing database outside local test fixture." >&2
    exit 1
fi
export PGPASSWORD="${VEDASENTIO_DB_PASSWORD:?}"
export VEDASENTIO_SMOKE_PORT="${VEDASENTIO_SMOKE_PORT:-28885}"

workdir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/vedasentio-sos-flood.XXXXXX")"
test_pid=""
broker_pid=""
test_log="$workdir/test.log"
broker_log="$workdir/mosquitto.log"

cleanup() {
    local code=$?
    trap - EXIT
    if ((code != 0)); then
        echo "[ALARM-MQTT] Test output:" >&2
        [[ ! -f "$test_log" ]] || tail -100 "$test_log" >&2
        echo "[ALARM-MQTT] Broker output:" >&2
        [[ ! -f "$broker_log" ]] || tail -60 "$broker_log" >&2
    fi
    if [[ -n "$test_pid" ]]; then
        kill "$test_pid" 2>/dev/null || true
        wait "$test_pid" 2>/dev/null || true
    fi
    if [[ -n "$broker_pid" ]]; then
        kill "$broker_pid" 2>/dev/null || true
        wait "$broker_pid" 2>/dev/null || true
    fi
    rm -rf -- "$workdir"
    exit "$code"
}
trap cleanup EXIT

echo "[ALARM-MQTT] Applying project PostgreSQL migrations..."
for migration in database/[0-9][0-9][0-9]_*.sql; do
    psql -h "$VEDASENTIO_DB_HOST" -p "$VEDASENTIO_DB_PORT" \
        -U "$VEDASENTIO_DB_USER" -d "$VEDASENTIO_DB_NAME" \
        -v ON_ERROR_STOP=1 -f "$migration" >/dev/null
done

echo "[ALARM-MQTT] Compiling production MQTT, parsing, alarm and database sources..."
g++ -std=c++20 -O1 -g -pthread -Wall -Wextra -Ibackend/src \
    backend/tools/mqtt_sos_flood_test.cpp \
    backend/src/mqtt/MqttClient.cpp \
    backend/src/mqtt/SensorEventParser.cpp \
    backend/src/database/Database.cpp \
    backend/src/alarms/AlarmRepository.cpp \
    -lpqxx -lpq -lpaho-mqttpp3 -lpaho-mqtt3as \
    -o "$workdir/test"

cat > "$workdir/mosquitto.conf" <<EOF
listener $VEDASENTIO_SMOKE_PORT 127.0.0.1
allow_anonymous true
persistence false
EOF
mosquitto -c "$workdir/mosquitto.conf" -v >"$broker_log" 2>&1 &
broker_pid=$!

for _ in $(seq 1 100); do
    if ! kill -0 "$broker_pid" 2>/dev/null; then
        echo "[ALARM-MQTT] Test broker exited unexpectedly" >&2
        exit 1
    fi
    if mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" \
        -t "ci/ready" -m "ready" >/dev/null 2>&1; then break; fi
    sleep 0.2
done

"$workdir/test" >"$test_log" 2>&1 &
test_pid=$!

marker() {
    local needle="$1"
    for _ in $(seq 1 150); do
        if grep -Fq "$needle" "$test_log"; then return 0; fi
        if ! kill -0 "$test_pid" 2>/dev/null; then
            echo "[ALARM-MQTT] Test process exited before $needle" >&2
            exit 1
        fi
        sleep 0.2
    done
    echo "[ALARM-MQTT] Timed out: $needle" >&2
    exit 1
}

publish() {
    local topic="$1" payload="$2"
    mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" \
        -q 1 -t "$topic" -m "$payload"
}

sos="vedasentio/home_alarm_ci/sos_ci/event"
flood="vedasentio/home_alarm_ci/flood_ci/event"
marker "[ALARM-MQTT] READY"

publish "$sos" '{"timestamp":"2026-11-22T10:00:00Z","event_type":"sos_pressed","value":true}'
marker "[ALARM-MQTT] SOS_OPENED"
publish "$sos" '{"timestamp":"2026-11-22T10:00:01Z","event_type":"sos_pressed","value":true}'
marker "[ALARM-MQTT] SOS_REPEAT_OK"
publish "$sos" '{"timestamp":"2026-11-22T10:00:02Z","event_type":"sos_resolved","value":false}'
marker "[ALARM-MQTT] SOS_RESOLVED"

# An unknown event and wrong boolean value must not create alarms or data.
publish "$sos" '{"timestamp":"2026-11-22T10:00:03Z","event_type":"unknown_test","value":true}'
publish "$sos" '{"timestamp":"2026-11-22T10:00:04Z","event_type":"sos_pressed","value":false}'
marker "[ALARM-MQTT] INVALID_REJECTED"
rejected_count="$(grep -Fc "[EVENT] Rejected:" "$test_log" || true)"
if ((rejected_count < 2)); then
    echo "[ALARM-MQTT] Expected two explicitly rejected MQTT messages, got $rejected_count" >&2
    exit 1
fi

publish "$flood" '{"timestamp":"2026-11-22T10:00:05Z","event_type":"flood_detected","value":true}'
marker "[ALARM-MQTT] FLOOD_OPENED"
publish "$flood" '{"timestamp":"2026-11-22T10:00:06Z","event_type":"flood_detected","value":true}'
marker "[ALARM-MQTT] FLOOD_REPEAT_OK"
publish "$flood" '{"timestamp":"2026-11-22T10:00:07Z","event_type":"flood_cleared","value":false}'

wait "$test_pid"
test_pid=""
grep -Fq "[ALARM-MQTT] PASS:" "$test_log"

# Fixture destructor must remove children before parent records; fail if it didn't.
remaining="$(psql -h "$VEDASENTIO_DB_HOST" -p "$VEDASENTIO_DB_PORT" \
    -U "$VEDASENTIO_DB_USER" -d "$VEDASENTIO_DB_NAME" -At \
    -c "SELECT (SELECT COUNT(*) FROM homes WHERE id='home_alarm_ci') +
               (SELECT COUNT(*) FROM sensor_events WHERE home_id='home_alarm_ci') +
               (SELECT COUNT(*) FROM alarms WHERE home_id='home_alarm_ci');")"
if [[ "$remaining" != "0" ]]; then
    echo "[ALARM-MQTT] Test rows were not cleaned up: $remaining" >&2
    exit 1
fi

echo "[ALARM-MQTT] PASS: SOS/flood, push outage, rejected messages, and fixture cleanup."
