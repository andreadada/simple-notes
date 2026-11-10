-- P2 attachments: additive cloud-only metadata. No existing note/task/outbox
-- data is modified. S3 staging and committed object keys are private.
CREATE TABLE note_attachment (
  id UUID PRIMARY KEY,
  owner_id UUID NOT NULL REFERENCES app_user(id),
  note_id UUID NOT NULL REFERENCES note(id),
  object_key VARCHAR(256) NOT NULL UNIQUE,
  file_name VARCHAR(180) NOT NULL,
  content_type VARCHAR(100) NOT NULL,
  size_bytes BIGINT NOT NULL CHECK (size_bytes BETWEEN 1 AND 10485760),
  state VARCHAR(16) NOT NULL CHECK (state IN ('PENDING','READY')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  pending_expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_note_attachment_owner_note
  ON note_attachment(owner_id, note_id, created_at DESC);
CREATE INDEX idx_note_attachment_pending
  ON note_attachment(pending_expires_at) WHERE state = 'PENDING';
