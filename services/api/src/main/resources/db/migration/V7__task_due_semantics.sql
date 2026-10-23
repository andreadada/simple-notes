-- Additive: older due_at values do not indicate whether midnight was intentional.
ALTER TABLE task ADD COLUMN due_kind VARCHAR(16) NOT NULL DEFAULT 'none';
ALTER TABLE task ADD COLUMN due_date DATE;
ALTER TABLE task ADD COLUMN due_time TIME;
ALTER TABLE task ADD COLUMN due_timezone VARCHAR(128);
ALTER TABLE task ADD COLUMN due_offset_seconds INTEGER;

UPDATE task SET due_kind = CASE WHEN due_at IS NULL THEN 'none' ELSE 'legacy' END;

ALTER TABLE task ADD CONSTRAINT chk_task_due_semantics CHECK (
    (due_kind = 'none' AND due_at IS NULL AND due_date IS NULL AND due_time IS NULL
        AND due_timezone IS NULL AND due_offset_seconds IS NULL)
 OR (due_kind = 'legacy' AND due_at IS NOT NULL AND due_date IS NULL AND due_time IS NULL
        AND due_timezone IS NULL AND due_offset_seconds IS NULL)
 OR (due_kind = 'date' AND due_at IS NULL AND due_date IS NOT NULL AND due_time IS NULL
        AND due_timezone IS NULL AND due_offset_seconds IS NULL)
 OR (due_kind = 'datetime' AND due_at IS NOT NULL AND due_date IS NOT NULL
        AND due_time IS NOT NULL AND due_timezone IS NOT NULL
        AND due_offset_seconds IS NOT NULL)
);
