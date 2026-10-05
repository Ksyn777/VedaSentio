# VedaSentio — Flutter mobile stage 03

## Goal

The third mobile stage adds a first interpretation layer above raw sensor
events.

Instead of showing only a list of events, the home screen now calculates
one of three safety states:

- `Wszystko OK`
- `Ostrzeżenie`
- `ALARM`

## Current MVP rules

### Alarm

The following events are treated as critical:

- `sos_pressed`
- `smoke_detected`
- `co_detected`
- `gas_detected`

SOS is a momentary user action. In the current MVP it raises an alarm for
15 minutes unless a future `sos_resolved` event appears earlier.

Smoke, CO and gas are treated as persistent hazards. They remain active
until a corresponding clearing event is received:

- `smoke_cleared`
- `co_cleared`
- `gas_cleared`

This avoids automatically declaring a potentially dangerous condition safe
only because time has passed.

### Warning

`flood_detected` creates an `Ostrzeżenie` state until `flood_cleared`.

### Informational events

Door events do not affect the home safety state:

- `door_opened`
- `door_closed`

They remain visible in the event history and can later be used by the
behaviour/routine analysis layer.

## Important limitation

This evaluator is an MVP interpretation rule set, not a medical or emergency
decision system.

`Wszystko OK` means only that no active alarm is present in the data currently
available to the application.

It does not prove that the monitored person is safe.

## Architecture

REST API events
    |
    v
SensorEvent
    |
    v
HomeSafetyEvaluator
    |
    +--> safe
    +--> warning
    +--> alarm
    |
    v
HomeDetailsScreen

The evaluator is separated from the UI and covered by unit tests.

## Future direction

The current deterministic rules are intentionally simple.

Later stages can move interpretation to the backend and extend it with:

- device heartbeat / offline detection,
- acknowledgement and alarm-resolution workflow,
- notification delivery,
- individualized daily routine models,
- deviation detection,
- long-term adaptive analysis.
