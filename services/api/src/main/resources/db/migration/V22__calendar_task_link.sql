-- Links are per owner and provider, no event deletion or token migration.
CREATE TABLE calendar_task_link (
 owner_id UUID NOT NULL REFERENCES app_user(id),
 task_id UUID NOT NULL REFERENCES task(id),
 provider VARCHAR(16) NOT NULL CHECK (provider IN ('google','microsoft')),
 event_id VARCHAR(512) NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 PRIMARY KEY(owner_id,task_id,provider),
 UNIQUE(owner_id,provider,event_id)
);
