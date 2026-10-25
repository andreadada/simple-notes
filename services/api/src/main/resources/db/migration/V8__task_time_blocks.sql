-- P1.2: optional, independent scheduled interval for a task.
-- Existing tasks stay unscheduled; do not infer from due_date/due_at.
ALTER TABLE task ADD COLUMN block_start_at TIMESTAMPTZ;
ALTER TABLE task ADD COLUMN block_end_at TIMESTAMPTZ;
ALTER TABLE task ADD COLUMN block_timezone VARCHAR(128);

ALTER TABLE task ADD CONSTRAINT chk_task_block_together CHECK (
  (block_start_at IS NULL AND block_end_at IS NULL AND block_timezone IS NULL)
  OR (block_start_at IS NOT NULL AND block_end_at IS NOT NULL
      AND block_timezone IS NOT NULL AND LENGTH(TRIM(block_timezone)) > 0
      AND block_end_at > block_start_at
      AND block_end_at <= block_start_at + INTERVAL '24 hours')
);
CREATE INDEX idx_task_owner_block_start ON task(owner_id, block_start_at)
  WHERE deleted_at IS NULL AND block_start_at IS NOT NULL;
