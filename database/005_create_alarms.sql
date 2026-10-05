-- VedaSentio migration 005
-- Persistent alarm objects derived from sensor events.

CREATE TABLE IF NOT EXISTS alarms
(
    id BIGSERIAL PRIMARY KEY,

    home_id TEXT NOT NULL,
    device_id TEXT NOT NULL,

    alarm_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',

    source_event_id BIGINT,
    last_event_id BIGINT,

    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    acknowledged_at TIMESTAMPTZ,
    acknowledged_by BIGINT,

    resolved_at TIMESTAMPTZ,
    resolved_by BIGINT,
    resolution_source TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT alarms_device_fk
        FOREIGN KEY (home_id, device_id)
        REFERENCES devices(home_id, id)
        ON DELETE CASCADE,

    CONSTRAINT alarms_source_event_fk
        FOREIGN KEY (source_event_id)
        REFERENCES sensor_events(id)
        ON DELETE SET NULL,

    CONSTRAINT alarms_last_event_fk
        FOREIGN KEY (last_event_id)
        REFERENCES sensor_events(id)
        ON DELETE SET NULL,

    CONSTRAINT alarms_acknowledged_by_fk
        FOREIGN KEY (acknowledged_by)
        REFERENCES users(id)
        ON DELETE SET NULL,

    CONSTRAINT alarms_resolved_by_fk
        FOREIGN KEY (resolved_by)
        REFERENCES users(id)
        ON DELETE SET NULL,

    CONSTRAINT alarms_type_check
        CHECK (alarm_type IN ('sos', 'smoke', 'co', 'gas', 'flood')),

    CONSTRAINT alarms_severity_check
        CHECK (severity IN ('warning', 'critical')),

    CONSTRAINT alarms_status_check
        CHECK (status IN ('active', 'acknowledged', 'resolved')),

    CONSTRAINT alarms_resolution_source_check
        CHECK
        (
            resolution_source IS NULL OR
            resolution_source IN ('sensor', 'user')
        )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_alarms_one_open_per_source
    ON alarms (home_id, device_id, alarm_type)
    WHERE status IN ('active', 'acknowledged');

CREATE INDEX IF NOT EXISTS idx_alarms_home_started
    ON alarms (home_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_alarms_home_status
    ON alarms (home_id, status, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_alarms_acknowledged_by
    ON alarms (acknowledged_by);
