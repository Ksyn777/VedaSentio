# VedaSentio — Flutter mobile stage 02

## Goal

The second mobile stage turns the home tile into a monitoring screen.

After the authenticated user taps a home, the app loads:

- `GET /api/homes/{home_id}/devices`
- `GET /api/homes/{home_id}/events?limit=20`
- `GET /api/homes/{home_id}/devices/{device_id}/latest`

The screen displays the home, assigned role, active device count, device list,
latest event for every device, and recent event history.

## Security

Every request still uses the JWT stored in `flutter_secure_storage`.
The mobile app never receives PostgreSQL or MQTT credentials.

HTTP 401 clears the local token and returns the user to the login flow.
HTTP 403 is presented as lack of access to the selected home.

## Current status semantics

For now a device is shown as active/inactive from the database `is_active`
flag and its latest known sensor event is displayed separately.

This is not yet connectivity health. A later stage should add heartbeat or
`last_seen` information to distinguish:

- active and communicating,
- active but offline,
- deliberately disabled.
