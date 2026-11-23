#!/usr/bin/env bash
set -euo pipefail

# Run only against a disposable local database and broker on a CI runner.
if [[ "${VEDASENTIO_DB_NAME:-}" != "vedasentio_mqtt_ci" ]] ||
   [[ "${VEDASENTIO_DB_HOST:-}" != "127.0.0.1" ]]; then
    echo "[PG] Refusing to run outside the disposable local CI database." >&2
    exit 1
fi

export VEDASENTIO_SMOKE_PORT="${VEDASENTIO_SMOKE_PORT:-28884}"
export PGPASSWORD="${VEDASENTIO_DB_PASSWORD:?}"
workdir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/vedasentio-mqtt-pg.XXXXXX")"
broker_pid=""
test_pid=""
test_log="$workdir/receiver.log"
broker_log="$workdir/broker.log"
binary="$workdir/mqtt_postgres_offline_test"

cleanup() {
    code=$?
    trap - EXIT
    if ((code != 0)); then
        echo "[PG] Smoke test failed; receiver log:" >&2
        [[ ! -f "$test_log" ]] || tail -100 "$test_log" >&2
        echo "[PG] Broker log:" >&2
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

echo "[PG] Migrating disposable database..."
for migration in database/[0-9][0-9][0-9]_*.sql; do
    psql -h "$VEDASENTIO_DB_HOST" -p "$VEDASENTIO_DB_PORT" \
      -U "$VEDASENTIO_DB_USER" -d "$VEDASENTIO_DB_NAME" \
      -v ON_ERROR_STOP=1 -f "$migration" >/dev/null
done

echo "[PG] Compiling production MQTT, database and alarm code..."
g++ -std=c++20 -O1 -g -pthread -Wall -Wextra \
    -Ibackend/src \
    backend/tools/mqtt_postgres_offline_test.cpp \
    backend/src/mqtt/MqttClient.cpp \
    backend/src/mqtt/SensorEventParser.cpp \
    backend/src/database/Database.cpp \
    backend/src/alarms/AlarmRepository.cpp \
    -lpqxx -lpq -lpaho-mqttpp3 -lpaho-mqtt3as \
    -o "$binary"

cat > "$workdir/mosquitto.conf" <<EOF
listener $VEDASENTIO_SMOKE_PORT 127.0.0.1
allow_anonymous true
persistence false
EOF

start_broker() {
    mosquitto -c "$workdir/mosquitto.conf" -v >>"$broker_log" 2>&1 &
    broker_pid=$!
    for _ in $(seq 1 100); do
        if ! kill -0 "$broker_pid" 2>/dev/null; then
            echo "[PG] Broker exited prematurely." >&2
            return 1
        fi
        if mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" \
            -t "_vedasentio_pg_ci/ready" -m "ready" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.2
    done
    echo "[PG] Broker was not ready." >&2
    return 1
}

wait_marker() {
    local text="$1" timeout="$2"
    for _ in $(seq 1 "$((timeout * 5))"); do
        if [[ -f "$test_log" ]] && grep -Fq "$text" "$test_log"; then
            return 0
        fi
        if [[ -n "$test_pid" ]] && ! kill -0 "$test_pid" 2>/dev/null; then
            echo "[PG] Test receiver exited before $text" >&2
            return 1
        fi
        sleep 0.2
    done
    echo "[PG] Timed out waiting for $text" >&2
    return 1
}

start_broker
"$binary" >"$test_log" 2>&1 &
test_pid=$!
wait_marker "[PG] INITIAL_SUBSCRIBED" 25

topic="vedasentio/home_ci/door_ci/event"
mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" -q 1 -t "$topic" \
    -m '{"timestamp":"2026-11-22T12:00:00Z","event_type":"heartbeat","value":true}'
wait_marker "[PG] INITIAL_HEARTBEAT_OK" 25

# Wrong JSON boolean type must not update last_seen or save an event.
mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" -q 1 -t "$topic" \
    -m '{"timestamp":"2026-11-22T12:00:01Z","event_type":"door_closed","value":"false"}'

# Reject a forged device ID and a registered but disabled device.
mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" -q 1 \
    -t "vedasentio/home_ci/unknown_ci/event" \
    -m '{"timestamp":"2026-11-22T12:00:01Z","event_type":"door_opened","value":true}'
mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" -q 1 \
    -t "vedasentio/home_ci/inactive_ci/event" \
    -m '{"timestamp":"2026-11-22T12:00:01Z","event_type":"door_opened","value":true}'
mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" -q 1 -t "$topic" \
    -m '{"timestamp":"2026-02-30T12:00:01Z","event_type":"door_opened","value":true}'
wait_marker "[PG] OFFLINE_ALARM_OPENED" 20
grep -Fq "is not registered" "$test_log"
grep -Fq "is inactive" "$test_log"
grep -Fq "must use UTC ISO-8601 format" "$test_log"

before="$(grep -Fc "[MQTT] Subscription requested:" "$test_log" || true)"
echo "[PG] Stopping disposable broker..."
kill "$broker_pid"
wait "$broker_pid" 2>/dev/null || true
broker_pid=""
wait_marker "[MQTT] Connection lost" 15

echo "[PG] Restarting disposable broker..."
start_broker
reconnected=0
for _ in $(seq 1 300); do
    count="$(grep -Fc "[MQTT] Subscription requested:" "$test_log" || true)"
    if ((count > before)); then
        reconnected=1
        break
    fi
    sleep 0.2
done
if ((reconnected == 0)); then
    echo "[PG] MQTT reconnect did not request a new subscription" >&2
    exit 1
fi

sleep 1
mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" -q 1 -t "$topic" \
    -m '{"timestamp":"2026-11-22T12:00:02Z","event_type":"heartbeat","value":true}'
wait_marker "[PG] HEARTBEAT_RESOLVED_OFFLINE" 25

# Test a second consecutive broker restart: automatic recovery must persist.
before="$(grep -Fc "[MQTT] Subscription requested:" "$test_log" || true)"
lost_before="$(grep -Fc "[MQTT] Connection lost" "$test_log" || true)"
echo "[PG] Repeating broker restart to catch stale callbacks/subscriptions..."
kill "$broker_pid"
wait "$broker_pid" 2>/dev/null || true
broker_pid=""
for _ in $(seq 1 75); do
    lost_count="$(grep -Fc "[MQTT] Connection lost" "$test_log" || true)"
    if ((lost_count > lost_before)); then break; fi
    sleep 0.2
done
if ((lost_count <= lost_before)); then
    echo "[PG] Second broker loss was not reported" >&2
    exit 1
fi
start_broker
reconnected=0
for _ in $(seq 1 300); do
    count="$(grep -Fc "[MQTT] Subscription requested:" "$test_log" || true)"
    if ((count > before)); then
        reconnected=1
        break
    fi
    sleep 0.2
done
if ((reconnected == 0)); then
    echo "[PG] Second reconnect did not resubscribe" >&2
    exit 1
fi
sleep 1

mosquitto_pub -h 127.0.0.1 -p "$VEDASENTIO_SMOKE_PORT" -q 1 -t "$topic" \
    -m '{"timestamp":"2026-11-22T12:00:03Z","event_type":"door_opened","value":true}'

wait "$test_pid"
test_pid=""
echo "[PG] PASS: one real offline alarm, heartbeat resolution, one DB event."
