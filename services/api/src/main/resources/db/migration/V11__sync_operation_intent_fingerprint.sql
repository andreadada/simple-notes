-- P2.4B2O: additive, backwards-compatible intent binding for NEW sync operations.
-- Historical operation rows are nullable; never rewrite, delete or fabricate
-- fingerprints for already-applied operations. This migration makes no data
-- changes to existing rows and does not require application downtime.
ALTER TABLE sync_operation
    ADD COLUMN request_fingerprint VARCHAR(64);
