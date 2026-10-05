CREATE TABLE IF NOT EXISTS mobile_push_tokens
(
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT mobile_push_tokens_platform_check
        CHECK (platform IN ('android', 'ios'))
);

CREATE INDEX IF NOT EXISTS idx_mobile_push_tokens_user_active
    ON mobile_push_tokens(user_id, is_active);
