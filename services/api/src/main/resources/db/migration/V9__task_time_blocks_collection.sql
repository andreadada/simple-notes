-- P1.4: schedule zero to twelve independent intervals per task.
-- Existing V8 columns remain the first-block mirror for older clients.
-- No rewrite of existing task rows, no change to sync history or volumes.
ALTER TABLE task ADD COLUMN blocks_json TEXT NOT NULL DEFAULT '[]';
