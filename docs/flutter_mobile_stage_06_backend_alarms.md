# VedaSentio — Flutter stage 06: backend-owned alarms

## Goal

This stage removes the mobile application as the authority for deciding
whether an alarm exists.

Previously the Flutter screen inferred the current safety state from recent
`sensor_events`.

After this stage the source of truth is the backend `alarms` lifecycle:

MQTT sensor event
-> C++ backend
-> PostgreSQL `alarms`
-> authenticated REST API
-> Flutter presentation

## API used by Flutter

The client loads:

- `GET /api/homes/{home_id}/alarms?active=true`
- `GET /api/homes/{home_id}/alarms?limit=20`

The first endpoint supplies the current alarm state.

The second supplies alarm history.

The technical event history remains available separately through
`/events`.

## Alarm acknowledgement

For users with the backend role `owner` or `caregiver`, Flutter exposes:

`Potwierdź alarm`

The action calls:

`POST /api/homes/{home_id}/alarms/{alarm_id}/acknowledge`

The backend stores the authenticated user ID and acknowledgement time.

Acknowledgement does not resolve the alarm.

The alarm remains active until the backend processes the matching resolution
event, for example `sos_resolved`.

## Why this architecture is preferable

A mobile client is not a reliable place for authoritative alarm state:

- it may be closed,
- multiple caregivers may use different phones,
- local clocks may differ,
- one client may temporarily lose network connectivity.

The backend is shared by all clients and receives the sensor events directly.
It therefore owns the alarm lifecycle.

Flutter is responsible for presenting the state and submitting authorized
user actions.

## User interface

The home screen now separates three concepts:

1. active alarms,
2. alarm history,
3. technical sensor-event history.

An active critical alarm keeps the main safety banner in the `ALARM` state
even after a caregiver acknowledges it.

This distinction is intentional:

`acknowledged != resolved`

## Current refresh mechanism

During development, the screen continues to poll the REST API every 3 seconds.

This is only for end-to-end verification.

The next production-oriented stage should introduce push notifications so
that a caregiver can be alerted while the application is in the background
or closed.
