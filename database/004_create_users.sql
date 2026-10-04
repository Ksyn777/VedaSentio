BEGIN;

CREATE TABLE IF NOT EXISTS users
(
    id BIGSERIAL PRIMARY KEY,
    email_encrypted TEXT NOT NULL,
    email_lookup_hmac CHAR(64) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    first_name_encrypted TEXT NOT NULL,
    last_name_encrypted TEXT NOT NULL,
    phone_encrypted TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_homes
(
    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    home_id TEXT NOT NULL
        REFERENCES homes(id)
        ON DELETE CASCADE,

    role TEXT NOT NULL DEFAULT 'caregiver'
        CHECK (role IN ('owner', 'caregiver', 'viewer')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (user_id, home_id)
);

CREATE INDEX IF NOT EXISTS idx_user_homes_home_id
    ON user_homes(home_id);

CREATE INDEX IF NOT EXISTS idx_users_active
    ON users(is_active);

COMMIT;
