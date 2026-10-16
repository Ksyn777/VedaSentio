-- VedaSentio migration 008
-- Adds a warning alarm type for devices that stop communicating.

ALTER TABLE alarms
    DROP CONSTRAINT IF EXISTS alarms_type_check;

ALTER TABLE alarms
    ADD CONSTRAINT alarms_type_check
        CHECK
        (
            alarm_type IN
            (
                'sos',
                'smoke',
                'co',
                'gas',
                'flood',
                'device_offline'
            )
        );
