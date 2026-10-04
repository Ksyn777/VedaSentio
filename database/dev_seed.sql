-- Development-only sample data for local testing.

INSERT INTO homes (id, name)
VALUES ('home_001', 'Dom testowy')
ON CONFLICT (id)
DO UPDATE SET
    name = EXCLUDED.name;

INSERT INTO devices
(
    home_id,
    id,
    device_type,
    name,
    is_active
)
VALUES
(
    'home_001',
    'sos_001',
    'sos_button',
    'Przycisk SOS',
    TRUE
)
ON CONFLICT (home_id, id)
DO UPDATE SET
    device_type = EXCLUDED.device_type,
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active;
