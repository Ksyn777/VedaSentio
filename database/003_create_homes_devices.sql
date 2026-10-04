-- VedaSentio migration 003
-- Adds registered homes and devices and links sensor events to them.

CREATE TABLE IF NOT EXISTS homes
(
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT homes_id_not_blank
        CHECK (BTRIM(id) <> '')
);

CREATE TABLE IF NOT EXISTS devices
(
    home_id TEXT NOT NULL,
    id TEXT NOT NULL,
    device_type TEXT NOT NULL,
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (home_id, id),

    CONSTRAINT devices_home_fk
        FOREIGN KEY (home_id)
        REFERENCES homes(id)
        ON DELETE CASCADE,

    CONSTRAINT devices_id_not_blank
        CHECK (BTRIM(id) <> ''),

    CONSTRAINT devices_type_not_blank
        CHECK (BTRIM(device_type) <> '')
);

-- Preserve compatibility with structured test events already stored
-- before the homes/devices model was introduced.
INSERT INTO homes (id, name)
SELECT DISTINCT
    home_id,
    'Imported home ' || home_id
FROM sensor_events
WHERE home_id IS NOT NULL
  AND BTRIM(home_id) <> ''
ON CONFLICT (id) DO NOTHING;

INSERT INTO devices (home_id, id, device_type, name)
SELECT DISTINCT
    home_id,
    device_id,
    'legacy',
    'Imported device ' || device_id
FROM sensor_events
WHERE home_id IS NOT NULL
  AND device_id IS NOT NULL
  AND BTRIM(home_id) <> ''
  AND BTRIM(device_id) <> ''
ON CONFLICT (home_id, id) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_devices_home_id
    ON devices (home_id);

CREATE INDEX IF NOT EXISTS idx_devices_type
    ON devices (device_type);

DO $$
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'sensor_events_home_fk'
    )
    THEN
        ALTER TABLE sensor_events
            ADD CONSTRAINT sensor_events_home_fk
            FOREIGN KEY (home_id)
            REFERENCES homes(id);
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'sensor_events_device_fk'
    )
    THEN
        ALTER TABLE sensor_events
            ADD CONSTRAINT sensor_events_device_fk
            FOREIGN KEY (home_id, device_id)
            REFERENCES devices(home_id, id);
    END IF;
END
$$;
