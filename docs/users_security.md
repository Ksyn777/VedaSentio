# VedaSentio — users and protected personal data

## Database model

The `users` table stores:
- encrypted e-mail address,
- deterministic HMAC lookup token for the normalized e-mail,
- Argon2id password hash,
- encrypted first name,
- encrypted last name,
- encrypted phone number,
- account activity flag,
- creation/update timestamps.

The `user_homes` table maps users to homes and contains the access role:
- owner,
- caregiver,
- viewer.

A user can therefore be authorized for selected homes instead of having
global access to every home in the system.

## Personal-data protection

The backend encrypts personal data before INSERT/UPDATE operations.

Protected fields:
- e-mail,
- first name,
- last name,
- phone.

The database does not need the plaintext value to locate a user by
e-mail. The normalized e-mail is transformed into an HMAC-SHA-256 lookup
token using a separate secret key.

This provides:
1. randomized encryption for stored personal data,
2. efficient exact lookup for selected encrypted identifiers,
3. separation of the encryption key and lookup key.

## Passwords

Passwords are not encrypted reversibly.

`PasswordHasher` uses libsodium Argon2id and stores its self-describing
encoded password hash in `users.password_hash`.

The encoded hash contains the salt and work parameters required for
verification. The original password is not stored.

## Development key persistence

The development scripts store the two crypto keys outside the Git
repository under the current Windows user's application-data directory.

The values are protected with Windows DPAPI through PowerShell's
SecureString mechanism.

The protected file can be decrypted only in the intended Windows user
context. It is not a production KMS replacement.

Production should use a dedicated secret manager/KMS and a documented
key-rotation process.

## Authorization model

`user_homes` is the future basis for API authorization.

Example:

User A -> home_001 -> caregiver
User B -> home_002 -> owner

After JWT authentication is added, every home-specific API route will
check this mapping before returning data.

## Current scope

This stage implements and tests:
- encrypted user storage,
- Argon2id password hashing,
- e-mail lookup through HMAC,
- user-to-home role mapping,
- persistent developer crypto secrets.

JWT and authenticated REST endpoints are intentionally left for the
next stage.
