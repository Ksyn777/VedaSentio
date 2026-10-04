ALTER TABLE sensor_events
    ADD COLUMN IF NOT EXISTS home_id TEXT,
    ADD COLUMN IF NOT EXISTS device_id TEXT,
    ADD COLUMN IF NOT EXISTS event_type TEXT,
    ADD COLUMN IF NOT EXISTS value JSONB,
    ADD COLUMN IF NOT EXISTS device_timestamp TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_sensor_events_home_received
    ON sensor_events (home_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_sensor_events_device_received
    ON sensor_events (device_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_sensor_events_event_type_received
    ON sensor_events (event_type, received_at DESC);
