package it.ddone.simplenotes.task;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** Versioned recurrence metadata; generation occurs on client completion. */
public record TaskRecurrence(String kind, int interval) {
    public static TaskRecurrence none() {
        return new TaskRecurrence("none", 1);
    }

    public static TaskRecurrence parse(JsonNode raw) {
        if (raw == null || !raw.isObject())
            throw invalid();
        JsonNode kind = raw.get("kind");
        if (kind == null || !kind.isTextual()) throw invalid();
        if ("none".equals(kind.asText())) {
            if (raw.has("interval") && (!raw.get("interval").isInt()
                    || raw.get("interval").intValue() != 1))
                throw invalid();
            return none();
        }
        if (!raw.has("interval") || !raw.get("interval").isInt()) throw invalid();
        int interval = raw.get("interval").intValue();
        if (!java.util.Set.of("daily", "weekly", "monthly").contains(kind.asText())
                || interval < 1 || interval > 12) throw invalid();
        return new TaskRecurrence(kind.asText(), interval);
    }

    public Map<String, Object> payload() {
        return "none".equals(kind) ? Map.of("kind", "none")
            : Map.of("kind", kind, "interval", interval);
    }

    private static ResponseStatusException invalid() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "Invalid recurrence rule");
    }
}
