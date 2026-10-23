-- Add organization metadata without changing or deleting existing tasks.
ALTER TABLE task_list ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE task ADD COLUMN priority INTEGER NOT NULL DEFAULT 0;
ALTER TABLE task ADD COLUMN tags_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE task ADD COLUMN subtasks_json TEXT NOT NULL DEFAULT '[]';
CREATE INDEX idx_task_owner_list ON task(owner_id, list_id) WHERE deleted_at IS NULL;
