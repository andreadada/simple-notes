-- Browser account preferences only, no mutation of native data or sync ledger.
CREATE TABLE web_preference (
 owner_id UUID NOT NULL REFERENCES app_user(id),
 domain VARCHAR(32) NOT NULL CHECK (domain IN ('theme','views','customViews','viewOptions','dashboards','habits','countdowns')),
 payload_json TEXT NOT NULL CHECK (octet_length(payload_json) <= 262144),
 version BIGINT NOT NULL CHECK (version > 0),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 PRIMARY KEY(owner_id,domain)
);
