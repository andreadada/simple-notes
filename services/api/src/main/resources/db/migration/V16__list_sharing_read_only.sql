-- P2 collaboration foundation: token-only, explicit opt-in, read-only shares.
-- Additive. The personal sync ledger/outbox and task ownership do not change.
CREATE TABLE list_share_invitation (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES app_user(id),
    list_id UUID NOT NULL REFERENCES task_list(id),
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    redeemed_by UUID REFERENCES app_user(id),
    redeemed_at TIMESTAMPTZ,
    CONSTRAINT ck_share_redemption CHECK (
        (redeemed_by IS NULL AND redeemed_at IS NULL)
        OR (redeemed_by IS NOT NULL AND redeemed_at IS NOT NULL)
    )
);
CREATE INDEX idx_list_share_invitation_owner
    ON list_share_invitation(owner_id, list_id, expires_at)
    WHERE revoked_at IS NULL AND redeemed_at IS NULL;

CREATE TABLE list_share_member (
    list_id UUID NOT NULL REFERENCES task_list(id),
    owner_id UUID NOT NULL REFERENCES app_user(id),
    member_id UUID NOT NULL REFERENCES app_user(id),
    role VARCHAR(16) NOT NULL DEFAULT 'VIEWER'
        CHECK (role IN ('VIEWER')),
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY(list_id, member_id),
    CONSTRAINT ck_share_not_owner CHECK (owner_id <> member_id)
);
CREATE INDEX idx_list_share_member_account
    ON list_share_member(member_id, accepted_at DESC);
