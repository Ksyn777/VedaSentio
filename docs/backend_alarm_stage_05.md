# VedaSentio — stage 05: persistent backend alarms

## Goal

Until this stage the Flutter client interpreted raw `sensor_events` and decided
whether the home was in a safe, warning or alarm state.

This stage introduces a persistent backend alarm domain model.

The backend now converts relevant sensor events into explicit `alarms` records.
The alarm state therefore exists independently of whether a mobile application
is currently open.

## Alarm lifecycle

Supported mappings:

- `sos_pressed` -> critical SOS alarm
- `sos_resolved` -> resolve SOS alarm
- `smoke_detected` -> critical smoke alarm
- `smoke_cleared` -> resolve smoke alarm
- `co_detected` -> critical CO alarm
- `co_cleared` -> resolve CO alarm
- `gas_detected` -> critical gas alarm
- `gas_cleared` -> resolve gas alarm
- `flood_detected` -> warning flood alarm
- `flood_cleared` -> resolve flood alarm

Door events remain informational and do not create alarms.

Only one unresolved alarm of the same type may exist for one device at a time.
Repeated detection events update the existing alarm instead of creating alarm
spam.

## Statuses

An alarm can have one of three states:

- `active` — created and not yet acknowledged,
- `acknowledged` — an owner/caregiver confirmed that they saw the alarm,
- `resolved` — the hazardous source reported that the condition ended.

Acknowledgement does not mean that the hazard is gone. For example, a gas
alarm remains an alarm after a caregiver acknowledges it. It is resolved only
when the corresponding sensor clearing event arrives.

## Authorization

New authenticated endpoints:

- `GET /api/homes/{home_id}/alarms`
- `GET /api/homes/{home_id}/alarms?active=true`
- `POST /api/homes/{home_id}/alarms/{alarm_id}/acknowledge`

Viewing requires access to the home.

Acknowledgement requires role:

- `owner`, or
- `caregiver`.

A `viewer` cannot acknowledge alarms.

## Data flow

sensor event
-> MQTT
-> device validation
-> `sensor_events` INSERT
-> event receives database ID
-> AlarmRepository
-> open/update/resolve `alarms`
-> authenticated REST API

## Why this matters

The mobile application is no longer required to reconstruct the authoritative
alarm lifecycle from raw historical events. This prepares the system for:

- push notifications,
- multiple caregivers,
- acknowledgement tracking,
- alarm history,
- audit logging,
- escalation policies.
