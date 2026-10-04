# VedaSentio — API authentication and authorization

## Scope

This stage adds authentication to the existing local REST API.

Public endpoints:
- GET /api/health
- POST /api/auth/login

Authenticated endpoints:
- GET /api/me
- GET /api/homes
- GET /api/homes/{home_id}/devices
- GET /api/homes/{home_id}/events
- GET /api/homes/{home_id}/devices/{device_id}/latest

## Login

The client sends an e-mail address and password to:

POST /api/auth/login

The backend:
1. normalizes the e-mail,
2. calculates its HMAC lookup token,
3. locates the encrypted user record,
4. verifies the password using Argon2id,
5. decrypts the authorized user's personal data,
6. creates a signed JWT access token.

The endpoint returns a generic `Invalid credentials` response for failed
authentication instead of revealing whether a specific e-mail address exists.

## JWT

The access token uses the standard three-part JWT structure:

Base64Url(header).Base64Url(payload).Base64Url(signature)

The implementation uses:
- algorithm: HS256,
- HMAC-SHA-256 signature through libsodium,
- 256-bit independent signing key,
- issuer validation,
- audience validation,
- issue time (`iat`),
- expiry time (`exp`),
- unique token identifier (`jti`),
- user ID in the `sub` claim,
- constant-time signature comparison.

Development access tokens expire after 3600 seconds.

The JWT signing key is independent from:
- the personal-data encryption key,
- the e-mail lookup HMAC key.

## Authorization

Successful authentication does not automatically grant access to every
home.

For a route containing `home_id`, the backend checks `user_homes`.

Example:

user 10 -> home_001 -> caregiver

The user may access resources belonging to `home_001` but a request for
a different unassigned home is rejected with HTTP 403.

`GET /api/homes` returns only homes assigned to the authenticated user.

## Account state

A JWT is validated on every protected request.

The backend also reloads the user from PostgreSQL and checks `is_active`.
This means disabling the account prevents use of an otherwise unexpired
access token.

## Secret storage

The existing Windows DPAPI development secret file is upgraded without
rotating the personal-data encryption keys.

A third independent value is added:
- VEDASENTIO_JWT_SIGNING_KEY_B64

Production should replace the development DPAPI mechanism with a
dedicated secret manager/KMS.

## Current limitations / next security work

The API is still bound to 127.0.0.1 for development.

Before exposing it over a network, the following are required:
- HTTPS/TLS,
- login rate limiting,
- production secret management,
- audit logging,
- deployment hardening.

Refresh tokens and server-side session revocation are not implemented in
this stage. Access tokens are intentionally short-lived.
