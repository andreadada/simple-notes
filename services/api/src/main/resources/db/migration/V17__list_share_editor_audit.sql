-- P2 EDITOR: additive role extension and immutable owner-scoped edit audit.
-- No task owner, personal sync cursor, or historical share is rewritten.
ALTER TABLE list_share_member
    DROP CONSTRAINT list_share_member_role_check;
ALTER TABLE list_share_member
    ADD CONSTRAINT list_share_member_role_check
    CHECK (role IN ('VIEWER', 'EDITOR'));

CREATE TABLE list_share_audit (
    id BIGSERIAL PRIMARY KEY,
    list_id UUID NOT NULL REFERENCES task_list(id),
    owner_id UUID NOT NULL REFERENCES app_user(id),
    actor_id UUID NOT NULL REFERENCES app_user(id),
    target_member_id UUID REFERENCES app_user(id),
    task_id UUID REFERENCES task(id),
    action VARCHAR(16) NOT NULL CHECK (action IN ('ROLE_CHANGE', 'TASK_EDIT')),
    detail VARCHAR(128) NOT NULL,
    sync_change_id BIGINT REFERENCES sync_change(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_list_share_audit_kind CHECK (
        (action = 'TASK_EDIT' AND task_id IS NOT NULL
            AND target_member_id IS NULL AND sync_change_id IS NOT NULL)
        OR
        (action = 'ROLE_CHANGE' AND task_id IS NULL
            AND target_member_id IS NOT NULL AND sync_change_id IS NULL)
    )
);
CREATE INDEX idx_list_share_audit_owner
    ON list_share_audit(owner_id, list_id, id DESC);
