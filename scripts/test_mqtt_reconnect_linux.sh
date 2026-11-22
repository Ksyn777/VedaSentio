#!/usr/bin/env bash
set -euo pipefail

# Fully isolated Linux smoke test; no production MQTT/DB credentials.
# Builds the real MqttClient.cpp and SensorEventParser.cpp unchanged.
port="${VEDASENTIO_SMOKE_PORT:-28883}"
if ! [[ "$port" =~ ^[0-9]+$ ]] || ((port < 1024 || port > 65535)); then
    echo "[SMOKE] Invalid test port" >&2
    exit 1
fi
export VEDASENTIO_SMOKE_PORT="$port"

workdir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/vedasentio-mqtt-smoke.XXXXXX")"
broker_pid=""
test_pid=""
test_log="$workdir/receiver.log"
broker_log="$workdir/broker.log"
binary="$workdir/mqtt_reconnect_smoke"

cleanup() {
    local code=$?
    trap - EXIT
    if ((code != 0)); then
        echo "[SMOKE] Failure; receiver output:" >&2
        if [[ -f "$test_log" ]]; then tail -100 "$test_log" >&2; fi
        echo "[SMOKE] Broker output:" >&2
        if [[ -f "$broker_log" ]]; then tail -50 "$broker_log" >&2; fi
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

cat > "$workdir/mosquitto.conf" <<EOF
listener $port 127.0.0.1
allow_anonymous true
persistence false
EOF

echo "[SMOKE] Building real MQTT client/parser with test-only storage stubs..."
g++ -std=c++20 -O1 -g -Wall -Wextra -pthread \
    -Ibackend/src \
    backend/tools/mqtt_reconnect_smoke.cpp \
    backend/src/mqtt/MqttClient.cpp \
    backend/src/mqtt/SensorEventParser.cpp \
    -lpaho-mqttpp3 -lpaho-mqtt3as \
    -o "$binary"

start_broker() {
    mosquitto -c "$workdir/mosquitto.conf" -v >> "$broker_log" 2>&1 &
    broker_pid=$!
    for _ in $(seq 1 100); do
        if ! kill -0 "$broker_pid" 2>/dev/null; then
            echo "[SMOKE] Broker exited unexpectedly" >&2
            return 1
        fi
        if mosquitto_pub -h 127.0.0.1 -p "$port" \
            -t "_vedasentio_smoke/ready" -m "ready" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.2
    done
    echo "[SMOKE] Broker did not start" >&2
    return 1
}

wait_for_marker() {
    local marker="$1"
    local max_seconds="$2"
    for _ in $(seq 1 "$((max_seconds * 5))"); do
        if [[ -f "$test_log" ]] && grep -Fq "$marker" "$test_log"; then
            return 0
        fi
        sleep 0.2
    done
    echo "[SMOKE] Timed out waiting for: $marker" >&2
    return 1
}

start_broker
"$binary" > "$test_log" 2>&1 &
test_pid=$!

wait_for_marker "[SMOKE] INITIAL_SUBSCRIBED" 25

topic="vedasentio/home_ci/door_ci/event"
mosquitto_pub -h 127.0.0.1 -p "$port" -q 1 -t "$topic" \
    -m '{"timestamp":"2026-11-22T12:00:00Z","event_type":"door_opened","value":true}'

wait_for_marker "[SMOKE] FIRST_EVENT_SAVED" 25

# Parser must discard this payload without touching the fake device state.
mosquitto_pub -h 127.0.0.1 -p "$port" -q 1 -t "$topic" \
    -m '{"timestamp":"2026-11-22T12:00:01Z","event_type":"door_closed","value":"false"}'

sleep 1
subscription_count="$(grep -Fc "[MQTT] Subscription requested:" "$test_log" || true)"

echo "[SMOKE] Stopping isolated broker..."
kill "$broker_pid"
wait "$broker_pid" 2>/dev/null || true
broker_pid=""
wait_for_marker "[MQTT] Connection lost" 15

echo "[SMOKE] Restarting isolated broker..."
start_broker
reconnected=0
for _ in $(seq 1 300); do
    current="$(grep -Fc "[MQTT] Subscription requested:" "$test_log" || true)"
    if ((current > subscription_count)); then
        reconnected=1
        break
    fi
    sleep 0.2
done
if ((reconnected == 0)); then
    echo "[SMOKE] Reconnect never requested subscription" >&2
    exit 1
fi

# Allow the asynchronous SUBACK to arrive before publishing.
sleep 1
mosquitto_pub -h 127.0.0.1 -p "$port" -q 1 -t "$topic" \
    -m '{"timestamp":"2026-11-22T12:00:02Z","event_type":"door_closed","value":false}'

wait_for_marker "[SMOKE] SECOND_EVENT_SAVED" 25
wait "$test_pid"
test_pid=""

echo "[SMOKE] PASS: real MqttClient survived broker restart and filtered invalid payload."
