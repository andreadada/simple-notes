-- P1.6 — additive recurrence metadata. No background scheduler,
-- task duplication, due date backfill or change to sync/owner IDs.
ALTER TABLE task ADD COLUMN recurrence_json TEXT NOT NULL
    DEFAULT '{"kind":"none"}';
