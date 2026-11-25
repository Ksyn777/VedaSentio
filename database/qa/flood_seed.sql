-- Synthetic device, applied only by the isolated QA integration runner.
INSERT INTO devices (home_id, id, device_type, name, is_active)
VALUES ('home_001', 'flood_001', 'flood_sensor', 'Czujnik zalania QA', TRUE)
ON CONFLICT (home_id, id) DO NOTHING;
