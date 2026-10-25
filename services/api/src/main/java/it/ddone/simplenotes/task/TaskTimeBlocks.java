package it.ddone.simplenotes.task;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** Stable IDs per scheduling interval, independent from due, title and task ID. */
public final class TaskTimeBlocks {
    private TaskTimeBlocks() {}
    public static final int MAX_BLOCKS = 12;
    public record Slot(String id, TaskTimeBlock block) {}

    private static ResponseStatusException invalid() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "Invalid timeBlocks: expected up to 12 uniquely identified UTC intervals");
    }

    public static List<Slot> parse(JsonNode raw) {
        if (raw == null || !raw.isArray() || raw.size() > MAX_BLOCKS)
            throw invalid();
        List<Slot> slots = new ArrayList<>();
        Set<String> ids = new HashSet<>();
        for (JsonNode item : raw) {
            if (!item.isObject() || !item.path("id").isTextual()) throw invalid();
            String id = item.get("id").textValue();
            try {
                if (!"legacy".equals(id)) UUID.fromString(id);
            } catch (IllegalArgumentException exception) { throw invalid(); }
            if (!ids.add(id)) throw invalid();
            ObjectNode wrapper = com.fasterxml.jackson.databind.node.JsonNodeFactory
                .instance.objectNode().put("kind", "range");
            wrapper.set("start", item.path("start"));
            wrapper.set("end", item.path("end"));
            wrapper.set("timeZone", item.path("timeZone"));
            slots.add(new Slot(id, TaskTimeBlock.parse(wrapper)));
        }
        return sort(slots);
    }

    private static List<Slot> sort(List<Slot> input) {
        List<Slot> result = new ArrayList<>(input);
        result.sort(Comparator.comparing((Slot x) -> x.block().start())
            .thenComparing(Slot::id));
        return List.copyOf(result);
    }

    public static List<Slot> fromEntity(TaskEntity task, ObjectMapper mapper) {
        try {
            List<Slot> slots = parse(mapper.readTree(task.blocksJson));
            // V8 rows have [] on V9 migration but still contain the prior
            // first block. Do not drop it on the first V9 update.
            if (slots.isEmpty() && task.blockStartAt != null) {
                return List.of(new Slot("legacy", TaskTimeBlock.fromEntity(task)));
            }
            return slots;
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Invalid stored task blocks", exception);
        }
    }

    public static List<Map<String, String>> toPayload(List<Slot> slots) {
        return sort(slots).stream().map(slot -> Map.of(
            "id", slot.id(), "start", slot.block().start().toString(),
            "end", slot.block().end().toString(),
            "timeZone", slot.block().timeZone())).toList();
    }

    public static void applyTo(TaskEntity task, List<Slot> slots,
            ObjectMapper mapper) {
        List<Slot> ordered = sort(slots);
        try {
            task.blocksJson = mapper.writeValueAsString(toPayload(ordered));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException(exception);
        }
        TaskTimeBlock.applyTo(task,
            ordered.isEmpty() ? null : ordered.get(0).block());
    }
}
