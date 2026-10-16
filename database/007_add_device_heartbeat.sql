-- VedaSentio migration 007
-- Adds device heartbeat state without storing every heartbeat as a sensor event.

ALTER TABLE devices
    ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

UPDATE devices AS device
SET last_seen_at = latest_event.last_received_at
FROM
(
    SELECT
        home_id,
        device_id,
        MAX(received_at) AS last_received_at
    FROM sensor_events
    GROUP BY home_id, device_id
) AS latest_event
WHERE device.home_id = latest_event.home_id
  AND device.id = latest_event.device_id
  AND device.last_seen_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_devices_last_seen_at
    ON devices (last_seen_at);
