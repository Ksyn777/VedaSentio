# VedaSentio — stage 04: end-to-end live alarm test

## Goal

This stage verifies the complete development data path:

simulated sensor
-> MQTT broker
-> C++ backend
-> PostgreSQL
-> authenticated REST API
-> Flutter
-> interpreted safety state

## Automatic refresh

`HomeDetailsScreen` now performs a silent refresh every 3 seconds while
the screen is open.

The automatic refresh:
- does not replace the existing screen with a loading spinner,
- does not overlap with another refresh,
- stops when the screen is disposed,
- preserves manual refresh and pull-to-refresh,
- displays the time of the last successful refresh.

This is a development polling mechanism. It is not the final notification
architecture.

## MQTT development event publisher

`scripts/mqtt_test_event.ps1` publishes a structured event using the same
MQTT topic convention as the sensor backend:

`vedasentio/{home_id}/{device_id}/event`

The script generates the current UTC timestamp automatically.

Example SOS:

`.\scripts\mqtt_test_event.ps1 -EventType sos_pressed -ValueJson "true"`

Example resolution:

`.\scripts\mqtt_test_event.ps1 -EventType sos_resolved -ValueJson "false"`

The MQTT password is never printed. If it is not already present in the
terminal environment, the script asks for it using a secure prompt.

## Expected end-to-end test

Initial state:

`Wszystko OK`

Publish:

`sos_pressed`

Expected within approximately 3 seconds:

`ALARM`

Then publish:

`sos_resolved`

Expected within approximately 3 seconds:

`Wszystko OK`

Both events remain in the event history.

## Important architectural note

The polling introduced here is deliberately temporary.

A production mobile application should not continuously poll a server every
3 seconds. Later stages should use push notifications for important alerts,
while normal screen data can be refreshed less frequently or on demand.

The purpose of this stage is to prove that the complete sensor-to-user path
works before adding notification infrastructure.
