-- P2 server-side inbox: opt-in reminder occurrences, shared acknowledgment.
-- Additive. No push credentials, local OS notifications, tasks or /sync modified.
CREATE TABLE server_reminder_preference (
    owner_id UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    lead_minutes INTEGER NOT NULL DEFAULT 15
        CHECK (lead_minutes IN (0, 5, 15, 30, 60, 1440)),
    version BIGINT NOT NULL DEFAULT 1 CHECK (version >= 1),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE server_reminder_occurrence (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES task(id) ON DELETE CASCADE,
    due_at TIMESTAMPTZ NOT NULL,
    fire_at TIMESTAMPTZ NOT NULL,
    lead_minutes INTEGER NOT NULL,
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_server_reminder_occurrence UNIQUE
        (owner_id, task_id, due_at, lead_minutes),
    CONSTRAINT ck_server_reminder_lead CHECK
        (lead_minutes IN (0, 5, 15, 30, 60, 1440))
);
CREATE INDEX idx_server_reminder_inbox
    ON server_reminder_occurrence(owner_id, fire_at DESC)
    WHERE acknowledged_at IS NULL;
CREATE INDEX idx_server_reminder_task
    ON server_reminder_occurrence(task_id, created_at DESC);
