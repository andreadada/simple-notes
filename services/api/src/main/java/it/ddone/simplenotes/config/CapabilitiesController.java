package it.ddone.simplenotes.config;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Authenticated clients check this before enabling the new task due format. */
@RestController
public class CapabilitiesController {
    @Value("${app.attachments.enabled:false}")
    private boolean attachmentsEnabled;

    @GetMapping("/api/v1/capabilities")
    public Map<String, Object> capabilities() {
        return Map.of("taskDueSchema", 1,
            "taskDueKinds", new String[]{"none", "date", "datetime", "legacy"},
            "requiresExplicitDueForModernTasks", true,
            "noteRestoreSchema", 1,
            "timeBlockSchema", 1,
            "timeBlocksSchema", 1,
            "recurrenceSchema", 1,
            "syncOperationFingerprintSchema", 1,
            "attachmentSchema", 1,
            "attachmentStorageEnabled", attachmentsEnabled);
    }
}
