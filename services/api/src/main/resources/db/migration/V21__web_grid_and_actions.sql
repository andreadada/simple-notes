-- Additive. Legacy clients omit customFields and keep stored values.
ALTER TABLE task ADD COLUMN custom_fields_json TEXT NOT NULL DEFAULT '{}';
ALTER TABLE task ADD CONSTRAINT task_custom_fields_size CHECK (octet_length(custom_fields_json) <= 32768);
ALTER TABLE web_preference DROP CONSTRAINT web_preference_domain_check;
ALTER TABLE web_preference ADD CONSTRAINT web_preference_domain_check CHECK (domain IN ('theme','views','customViews','viewOptions','dashboards','habits','countdowns','gridColumns','customFields','automationEnabled'));
