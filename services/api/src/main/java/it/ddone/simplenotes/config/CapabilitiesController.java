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
        return Map.ofEntries(Map.entry("taskDueSchema", 1),
            Map.entry("taskDueKinds", new String[]{"none", "date", "datetime", "legacy"}),
            Map.entry("requiresExplicitDueForModernTasks", true),
            Map.entry("noteRestoreSchema", 1),
            Map.entry("timeBlockSchema", 1),
            Map.entry("timeBlocksSchema", 1),
            Map.entry("recurrenceSchema", 1),
            Map.entry("syncOperationFingerprintSchema", 1),
            Map.entry("attachmentSchema", 1),
            Map.entry("attachmentStorageEnabled", attachmentsEnabled),
            Map.entry("sharingReadSchema", 1),
            Map.entry("sharingEditorSchema", 1),
            Map.entry("calendarReadSchema", 1));
    }
}
