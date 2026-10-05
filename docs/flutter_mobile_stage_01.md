# VedaSentio — Flutter mobile stage 01

Implemented mobile flow:

1. login screen,
2. POST `/api/auth/login`,
3. secure JWT storage using `flutter_secure_storage`,
4. session restoration after app restart,
5. GET `/api/me`,
6. GET `/api/homes`,
7. list of homes assigned to the authenticated user,
8. logout by deleting the local token.

The mobile application does not receive PostgreSQL or MQTT credentials.

For Android development the backend can remain bound to `127.0.0.1:8080`.
`adb reverse tcp:8080 tcp:8080` forwards the Android device/emulator's
localhost port to the Windows host localhost port. This avoids exposing the
development API to the LAN.

Cleartext HTTP is allowed only in `android/app/src/debug/AndroidManifest.xml`.
Production must use HTTPS/TLS.
