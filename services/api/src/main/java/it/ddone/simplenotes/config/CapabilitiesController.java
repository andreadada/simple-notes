package it.ddone.simplenotes.config;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Authenticated clients check this before enabling the new task due format. */
@RestController
public class CapabilitiesController {
    @GetMapping("/api/v1/capabilities")
    public Map<String, Object> capabilities() {
        return Map.of("taskDueSchema", 1,
            "taskDueKinds", new String[]{"none", "date", "datetime", "legacy"},
            "requiresExplicitDueForModernTasks", true,
            "noteRestoreSchema", 1,
            "timeBlockSchema", 1,
            "timeBlocksSchema", 1,
            "recurrenceSchema", 1);
    }
}
