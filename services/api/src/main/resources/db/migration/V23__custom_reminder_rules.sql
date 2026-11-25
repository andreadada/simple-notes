-- Existing V19 preference stays available when custom rule mode is disabled.
CREATE TABLE web_reminder_config (
 owner_id UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
 enabled BOOLEAN NOT NULL DEFAULT FALSE,
 version BIGINT NOT NULL CHECK (version > 0),
 rules_json TEXT NOT NULL CHECK (octet_length(rules_json) <= 32768),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE web_reminder_occurrence (
 id UUID PRIMARY KEY,
 owner_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
 task_id UUID NOT NULL REFERENCES task(id) ON DELETE CASCADE,
 config_version BIGINT NOT NULL,
 rule_id VARCHAR(90) NOT NULL,
 kind VARCHAR(8) NOT NULL CHECK (kind IN ('due','block')),
 slot_id VARCHAR(36) NOT NULL,
 scheduled_at TIMESTAMPTZ NOT NULL,
 fire_at TIMESTAMPTZ NOT NULL,
 lead_minutes INTEGER NOT NULL CHECK (lead_minutes IN (0,5,15,30,60,1440)),
 acknowledged_at TIMESTAMPTZ,
 UNIQUE(owner_id,task_id,config_version,rule_id,slot_id,scheduled_at)
);
CREATE INDEX web_reminder_unread ON web_reminder_occurrence(owner_id,fire_at DESC) WHERE acknowledged_at IS NULL;
