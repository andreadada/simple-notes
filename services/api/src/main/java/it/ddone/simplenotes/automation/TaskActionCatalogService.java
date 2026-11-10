package it.ddone.simplenotes.automation;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Versioned, account-isolated catalog exchange.
 *
 * PostgreSQL's per-account transaction advisory lock serializes the
 * empty-row insert race as well as concurrent updates. Every PUT is a CAS:
 * stale clients get 409 and must inspect before choosing what to keep.
 * There is deliberately no scheduled execution on the API.
 */
@Service
public class TaskActionCatalogService {
    private final TaskActionCatalogRepository repository;
    private final EntityManager entityManager;
    private final ObjectMapper json;

    public TaskActionCatalogService(TaskActionCatalogRepository repository,
            EntityManager entityManager, ObjectMapper json) {
        this.repository = repository;
        this.entityManager = entityManager;
        this.json = json;
    }

    @Transactional(readOnly = true)
    public TaskActionCatalogController.Snapshot read(UUID owner) {
        return repository.findById(owner).map(catalog ->
            new TaskActionCatalogController.Snapshot(
                catalog.version, parse(catalog.payloadJson))
        ).orElseGet(() -> new TaskActionCatalogController.Snapshot(
            0, json.createObjectNode().put("schema", 1)
                .set("rules", json.createArrayNode())));
    }

    @Transactional
    public TaskActionCatalogController.Snapshot replace(UUID owner,
            TaskActionCatalogController.Replace request) {
        // The same lock strategy as the main sync service. The identity is
        // passed as a query parameter; no SQL interpolation.
        entityManager.createNativeQuery(
            "SELECT pg_advisory_xact_lock(hashtext(:owner))")
            .setParameter("owner", owner.toString()).getSingleResult();

        var existing = repository.findById(owner).orElse(null);
        long current = existing == null ? 0 : existing.version;
        if (request.expectedVersion() != current) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Automation catalog revision changed");
        }
        if (current == Long.MAX_VALUE) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Automation catalog revision exhausted");
        }

        var encoded = validateAndEncode(request.catalog());
        if (existing == null) {
            existing = new TaskActionCatalogEntity(owner, encoded);
        } else {
            existing.payloadJson = encoded;
            existing.version = current + 1;
            existing.updatedAt = Instant.now();
        }
        repository.saveAndFlush(existing);
        return new TaskActionCatalogController.Snapshot(
            existing.version, parse(existing.payloadJson));
    }

    private JsonNode parse(String source) {
        try {
            var catalog = json.readTree(source);
            validateAndEncode(catalog);
            return catalog;
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Stored automation catalog invalid");
        }
    }

    /** Mirror the strict local Flutter v1 contract, including size limits. */
    private String validateAndEncode(JsonNode catalog) {
        if (catalog == null || !catalog.isObject() ||
                catalog.size() != 2 ||
                !catalog.path("schema").isIntegralNumber() ||
                catalog.path("schema").asInt() != 1 ||
                !catalog.path("rules").isArray() ||
                catalog.path("rules").size() > 20) {
            throw invalid();
        }
        Set<String> ids = new HashSet<>();
        for (JsonNode rule : catalog.path("rules")) {
            if (!rule.isObject() || rule.size() != 6 ||
                    !text(rule, "id") || !text(rule, "trigger") ||
                    !text(rule, "action") || !text(rule, "value") ||
                    !text(rule, "titleContains") ||
                    !rule.path("enabled").isBoolean()) {
                throw invalid();
            }
            String id = rule.path("id").textValue();
            String trigger = rule.path("trigger").textValue();
            String action = rule.path("action").textValue();
            String value = rule.path("value").textValue();
            String title = rule.path("titleContains").textValue();
            if (!id.matches("action-[a-zA-Z0-9-]{3,90}") ||
                    !ids.add(id) ||
                    !(trigger.equals("created") || trigger.equals("completed")) ||
                    !(action.equals("priority") || action.equals("tag") ||
                        action.equals("list")) ||
                    title.length() > 100 || !title.equals(title.trim()) ||
                    value.isEmpty() || value.length() > 128 ||
                    !value.equals(value.trim())) {
                throw invalid();
            }
            if (action.equals("priority") &&
                    !Set.of("0", "1", "2", "3").contains(value)) {
                throw invalid();
            }
            if (action.equals("tag") &&
                    (value.length() > 40 || value.contains(",") ||
                        value.contains("\n") || value.isBlank())) {
                throw invalid();
            }
            if (action.equals("list")) {
                try {
                    // List IDs are UUIDs. Do not check existence here: a list
                    // may be created later on another device.
                    UUID.fromString(value);
                } catch (IllegalArgumentException exception) {
                    throw invalid();
                }
            }
        }
        try {
            String encoded = json.writeValueAsString(catalog);
            if (encoded.getBytes(StandardCharsets.UTF_8).length > 32768) {
                throw invalid();
            }
            return encoded;
        } catch (JsonProcessingException exception) {
            throw invalid();
        }
    }

    private static boolean text(JsonNode node, String name) {
        return node.has(name) && node.get(name).isTextual();
    }

    private static ResponseStatusException invalid() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "Automation catalog format invalid");
    }
}
