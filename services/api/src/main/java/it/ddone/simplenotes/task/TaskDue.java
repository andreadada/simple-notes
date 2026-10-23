package it.ddone.simplenotes.task;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Civil dates are not instants. A timed due date has an IANA zone, an explicit
 * selected UTC offset (for the DST overlap) and a matching UTC instant.
 * Legacy instants are intentionally never inferred as date-only.
 */
public record TaskDue(String kind, LocalDate date, LocalTime time, String timeZone,
                      Instant instant, Integer offsetSeconds) {

    public static TaskDue fromEntity(TaskEntity entity) {
        return new TaskDue(entity.dueKind, entity.dueDate, entity.dueTime,
            entity.dueTimezone, entity.dueAt, entity.dueOffsetSeconds);
    }

    public static TaskDue fromOldInstant(Instant instant) {
        return instant == null
            ? new TaskDue("none", null, null, null, null, null)
            : new TaskDue("legacy", null, null, null, instant, null);
    }

    public static TaskDue parse(JsonNode node) {
        if (node == null || !node.isObject()) throw invalid();
        String kind = requiredString(node, "kind");
        try {
            return switch (kind) {
                case "none" -> {
                    onlyKeys(node, "kind");
                    yield fromOldInstant(null);
                }
                case "date" -> {
                    onlyKeys(node, "kind", "date");
                    yield new TaskDue("date", LocalDate.parse(requiredString(node, "date"),
                        DateTimeFormatter.ISO_LOCAL_DATE), null, null, null, null);
                }
                case "legacy" -> {
                    onlyKeys(node, "kind", "instant");
                    yield new TaskDue("legacy", null, null, null,
                        Instant.parse(requiredString(node, "instant")), null);
                }
                case "datetime" -> {
                    onlyKeys(node, "kind", "date", "time", "timeZone", "instant", "offsetSeconds");
                    LocalDate date = LocalDate.parse(requiredString(node, "date"),
                        DateTimeFormatter.ISO_LOCAL_DATE);
                    String timeString = requiredString(node, "time");
                    if (!timeString.matches("[0-9]{2}:[0-9]{2}")) throw invalid();
                    LocalTime time = LocalTime.parse(timeString, DateTimeFormatter.ofPattern("HH:mm"));
                    String zoneName = requiredString(node, "timeZone");
                    if (!ZoneId.getAvailableZoneIds().contains(zoneName)) throw invalid();
                    ZoneId zone = ZoneId.of(zoneName);
                    JsonNode offsetNode = node.get("offsetSeconds");
                    if (offsetNode == null || !offsetNode.isIntegralNumber() || !offsetNode.canConvertToInt())
                        throw invalid();
                    int offsetSeconds = offsetNode.intValue();
                    ZoneOffset selected = ZoneOffset.ofTotalSeconds(offsetSeconds);
                    List<ZoneOffset> possible = zone.getRules().getValidOffsets(LocalDateTime.of(date, time));
                    if (!possible.contains(selected)) throw invalid();
                    Instant instant = Instant.parse(requiredString(node, "instant"));
                    if (!LocalDateTime.of(date, time).toInstant(selected).equals(instant)) throw invalid();
                    yield new TaskDue("datetime", date, time, zoneName, instant, offsetSeconds);
                }
                default -> throw invalid();
            };
        } catch (DateTimeException exception) {
            throw invalid();
        }
    }

    public void applyTo(TaskEntity task) {
        task.dueKind = kind;
        task.dueDate = date;
        task.dueTime = time;
        task.dueTimezone = timeZone;
        task.dueOffsetSeconds = offsetSeconds;
        task.dueAt = instant;
    }

    public Map<String, Object> toPayload() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("kind", kind);
        if (date != null) result.put("date", date.toString());
        if (time != null) result.put("time", time.format(DateTimeFormatter.ofPattern("HH:mm")));
        if (timeZone != null) result.put("timeZone", timeZone);
        if (instant != null) result.put("instant", instant.toString());
        if (offsetSeconds != null) result.put("offsetSeconds", offsetSeconds);
        return result;
    }

    private static String requiredString(JsonNode value, String name) {
        JsonNode property = value.get(name);
        if (property == null || !property.isTextual() || property.textValue().isBlank())
            throw invalid();
        return property.textValue();
    }

    private static void onlyKeys(JsonNode value, String... allowed) {
        Set<String> names = Set.of(allowed);
        Iterator<String> fields = value.fieldNames();
        while (fields.hasNext()) {
            if (!names.contains(fields.next())) throw invalid();
        }
    }

    private static ResponseStatusException invalid() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid task due specification");
    }
}
