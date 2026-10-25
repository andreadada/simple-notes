package it.ddone.simplenotes.task;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** Optional scheduling interval, deliberately independent from the task due date. */
public record TaskTimeBlock(Instant start, Instant end, String timeZone) {
    public static TaskTimeBlock parse(JsonNode value) {
        if (value == null || !value.isObject())
            throw invalid();
        String kind = value.path("kind").asText("");
        if ("none".equals(kind)) {
            if (value.size() != 1) throw invalid();
            return null;
        }
        if (!"range".equals(kind) || !value.path("start").isTextual() ||
                !value.path("end").isTextual() ||
                !value.path("timeZone").isTextual()) throw invalid();
        try {
            Instant start = Instant.parse(value.get("start").textValue());
            Instant end = Instant.parse(value.get("end").textValue());
            String zone = value.get("timeZone").textValue();
            if (zone.length() > 128 || zone.isBlank()) throw invalid();
            ZoneId.of(zone);
            Duration length = Duration.between(start, end);
            if (length.isNegative() || length.isZero() ||
                    length.compareTo(Duration.ofHours(24)) > 0) throw invalid();
            if (start.getNano() != 0 || end.getNano() != 0) throw invalid();
            return new TaskTimeBlock(start, end, zone);
        } catch (RuntimeException ex) {
            throw invalid();
        }
    }

    public static TaskTimeBlock fromEntity(TaskEntity task) {
        if (task.blockStartAt == null) return null;
        return new TaskTimeBlock(task.blockStartAt, task.blockEndAt, task.blockTimezone);
    }

    public static Object toPayload(TaskEntity task) {
        TaskTimeBlock block = fromEntity(task);
        return block == null
            ? java.util.Map.of("kind", "none")
            : java.util.Map.of("kind", "range", "start", block.start.toString(),
                "end", block.end.toString(), "timeZone", block.timeZone);
    }

    public static void applyTo(TaskEntity entity, TaskTimeBlock block) {
        entity.blockStartAt = block == null ? null : block.start;
        entity.blockEndAt = block == null ? null : block.end;
        entity.blockTimezone = block == null ? null : block.timeZone;
    }

    private static ResponseStatusException invalid() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "Invalid time block; expected kind none or UTC range <= 24h with IANA time zone");
    }
}
