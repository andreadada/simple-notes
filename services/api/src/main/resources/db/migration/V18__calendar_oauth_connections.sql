-- Additive P2 calendar OAuth links. Tokens and PKCE verifiers are AES-GCM encrypted.
-- No existing tasks, notes, sync operations or auth sessions change.
CREATE TABLE calendar_oauth_attempt (
    state_hash CHAR(64) PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    provider VARCHAR(16) NOT NULL CHECK (provider IN ('google', 'microsoft')),
    verifier_encrypted TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_calendar_oauth_attempt_owner
    ON calendar_oauth_attempt(owner_id, expires_at);

CREATE TABLE calendar_oauth_connection (
    owner_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    provider VARCHAR(16) NOT NULL CHECK (provider IN ('google', 'microsoft')),
    access_token_encrypted TEXT NOT NULL,
    refresh_token_encrypted TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (owner_id, provider)
);
