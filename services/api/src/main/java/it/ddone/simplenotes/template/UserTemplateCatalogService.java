package it.ddone.simplenotes.template;

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

/** Explicit owner-scoped GET/PUT, PostgreSQL-serialized CAS, strict schema. */
@Service
public class UserTemplateCatalogService {
    private final UserTemplateCatalogRepository repository;
    private final EntityManager em;
    private final ObjectMapper json;

    public UserTemplateCatalogService(UserTemplateCatalogRepository repository,
            EntityManager em, ObjectMapper json) {
        this.repository = repository;
        this.em = em;
        this.json = json;
    }

    @Transactional(readOnly = true)
    public UserTemplateCatalogController.Snapshot read(UUID owner) {
        return repository.findById(owner).map(row ->
            new UserTemplateCatalogController.Snapshot(
                row.version, parse(row.payloadJson))
        ).orElseGet(() -> new UserTemplateCatalogController.Snapshot(
            0, json.createObjectNode().put("schema", 1)
                .set("templates", json.createArrayNode())));
    }

    @Transactional
    public UserTemplateCatalogController.Snapshot replace(UUID owner,
            UserTemplateCatalogController.Replace request) {
        // Serialize first insert and subsequent updates for this owner.
        em.createNativeQuery("SELECT pg_advisory_xact_lock(hashtext(:key))")
            .setParameter("key", "user_template_catalog:" + owner)
            .getSingleResult();
        var old = repository.findById(owner).orElse(null);
        long version = old == null ? 0 : old.version;
        if (request.expectedVersion() != version || version == Long.MAX_VALUE) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Template catalog revision changed");
        }
        String validated = validateAndEncode(request.catalog());
        if (old == null) old = new UserTemplateCatalogEntity(owner, validated);
        else {
            old.payloadJson = validated;
            old.version = version + 1;
            old.updatedAt = Instant.now();
        }
        repository.saveAndFlush(old);
        return new UserTemplateCatalogController.Snapshot(
            old.version, parse(old.payloadJson));
    }

    private JsonNode parse(String source) {
        try {
            var tree = json.readTree(source);
            validateAndEncode(tree);
            return tree;
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Stored template catalog invalid", exception);
        }
    }

    private String validateAndEncode(JsonNode catalog) {
        if (catalog == null || !catalog.isObject() || catalog.size() != 2
                || !catalog.path("schema").isIntegralNumber()
                || catalog.path("schema").asInt() != 1
                || !catalog.path("templates").isArray()
                || catalog.path("templates").size() > 50) throw invalid();
        Set<String> ids = new HashSet<>();
        for (JsonNode t : catalog.path("templates")) {
            if (!t.isObject() || t.size() != 6
                    || !str(t, "id") || !str(t, "title")
                    || !str(t, "description") || !t.path("priority").isIntegralNumber()
                    || !t.path("tags").isArray()
                    || !t.path("subtasks").isArray()) throw invalid();
            String id = t.path("id").asText();
            String title = t.path("title").asText();
            String description = t.path("description").asText();
            int priority = t.path("priority").asInt();
            if (!id.startsWith("custom-") || id.length() > 90
                    || !ids.add(id) || title.isBlank()
                    || title.length() > 160 || !title.equals(title.trim())
                    || description.length() > 2000 || priority < 0 || priority > 3
                    || t.path("tags").size() > 16
                    || t.path("subtasks").size() > 50) throw invalid();
            Set<String> subtasks = new HashSet<>();
            for (JsonNode tag : t.path("tags")) {
                if (!tag.isTextual() || tag.asText().isBlank()
                        || tag.asText().length() > 40) throw invalid();
            }
            for (JsonNode subtask : t.path("subtasks")) {
                if (!subtask.isTextual() || subtask.asText().isBlank()
                        || subtask.asText().length() > 255
                        || !subtasks.add(subtask.asText())) throw invalid();
            }
        }
        try {
            String content = json.writeValueAsString(catalog);
            if (content.getBytes(StandardCharsets.UTF_8).length > 131072) {
                throw invalid();
            }
            return content;
        } catch (JsonProcessingException exception) {
            throw invalid();
        }
    }

    private static boolean str(JsonNode item, String name) {
        return item.has(name) && item.get(name).isTextual();
    }

    private static ResponseStatusException invalid() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "Template catalog schema invalid");
    }
}
