package it.ddone.simplenotes;

import it.ddone.simplenotes.user.AppUser;
import it.ddone.simplenotes.user.AppUserRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class SyncIntegrationTest {
    @Container static final PostgreSQLContainer<?> pg =
        new PostgreSQLContainer<>("postgres:17-alpine");
    @DynamicPropertySource
    static void props(DynamicPropertyRegistry p) {
        p.add("spring.datasource.url", pg::getJdbcUrl);
        p.add("spring.datasource.username", pg::getUsername);
        p.add("spring.datasource.password", pg::getPassword);
        p.add("app.google.client-ids", () -> "test-google-client");
        p.add("app.jwt.secret-base64", () -> "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVoxMjM0NTY=");
    }
    @Autowired MockMvc mvc;
    @Autowired AppUserRepository users;
    @Autowired JwtEncoder encoder;
    @Autowired ObjectMapper mapper;
    @Autowired JdbcTemplate jdbc;

    String jwt(UUID id) {
        Instant now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("simple-notes-api")
            .audience(List.of("simple-notes")).subject(id.toString())
            .issuedAt(now).expiresAt(now.plusSeconds(600)).build();
        return encoder.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    @Test
    void applyIsIdempotentAndDeltaIsPrivate() throws Exception {
        var a = users.save(new AppUser("sync-a-" + UUID.randomUUID(), "a@example.com", "A"));
        var b = users.save(new AppUser("sync-b-" + UUID.randomUUID(), "b@example.com", "B"));
        String operationId = UUID.randomUUID().toString();
        String entityId = UUID.randomUUID().toString();
        String request = "{\"operationId\":\"" + operationId + "\",\"entityId\":\"" + entityId +
            "\",\"entityType\":\"task\",\"action\":\"upsert\",\"payload\":{\"title\":\"Buy milk\",\"completed\":false}}";
        String path = "/api/v1/sync/apply";
        mvc.perform(post(path).header("Authorization", "Bearer " + jwt(a.id))
            .contentType(MediaType.APPLICATION_JSON).content(request))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));
        mvc.perform(post(path).header("Authorization", "Bearer " + jwt(a.id))
            .contentType(MediaType.APPLICATION_JSON).content(request))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", "Bearer " + jwt(a.id)))
            .andExpect(status().isOk()).andExpect(jsonPath("$.changes.length()").value(1))
            .andExpect(jsonPath("$.changes[0].payload.title").value("Buy milk"));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", "Bearer " + jwt(b.id)))
            .andExpect(status().isOk()).andExpect(jsonPath("$.changes.length()").value(0));
        mvc.perform(post(path).header("Authorization", "Bearer " + jwt(b.id))
            .contentType(MediaType.APPLICATION_JSON).content(request))
            .andExpect(status().isConflict());
    }
    @Test
    void noteCreatedOnDeviceAIsVisibleToDeviceBAndCanBeEdited() throws Exception {
        var user = users.save(new AppUser("note-sync-" + UUID.randomUUID(),
            "note@example.com", "Two devices"));
        String bearer = "Bearer " + jwt(user.id);
        String entity = UUID.randomUUID().toString();
        String op1 = UUID.randomUUID().toString();
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"","body":"Nota creata su PC"}}
            """.formatted(op1, entity);
        mvc.perform(post("/api/v1/sync/apply")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(0));

        // Different device with the *same user* downloads the note.
        mvc.perform(get("/api/v1/sync/changes")
                .header("Authorization", bearer).param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(1))
            .andExpect(jsonPath("$.changes[0].entityType").value("note"))
            .andExpect(jsonPath("$.changes[0].payload.body").value("Nota creata su PC"))
            .andExpect(jsonPath("$.changes[0].payload.title").value(""));

        String op2 = UUID.randomUUID().toString();
        String update = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Aggiornata","body":"Modificata su Android"}}
            """.formatted(op2, entity);
        mvc.perform(post("/api/v1/sync/apply")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(update))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1));

        // The first device can pull the subsequent version without losing data.
        mvc.perform(get("/api/v1/sync/changes")
                .header("Authorization", bearer).param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(2))
            .andExpect(jsonPath("$.changes[1].payload.body").value("Modificata su Android"))
            .andExpect(jsonPath("$.changes[1].version").value(1));
    }

    @Test
    void deletedNoteCanBeExplicitlyRestoredWithOriginalIdentityAndVersion() throws Exception {
        var owner = users.save(new AppUser("restore-note-" + UUID.randomUUID(),
            "restore@example.com", "Restore"));
        var other = users.save(new AppUser("restore-other-" + UUID.randomUUID(),
            "other@example.com", "Other"));
        String bearer = "Bearer " + jwt(owner.id);
        String entity = UUID.randomUUID().toString();
        String endpoint = "/api/v1/sync/apply";

        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Da recuperare","body":"Testo integro"}}
            """.formatted(UUID.randomUUID(), entity);
        mvc.perform(post(endpoint).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));

        String delete = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"delete","expectedVersion":0}
            """.formatted(UUID.randomUUID(), entity);
        mvc.perform(post(endpoint).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(delete))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));

        String restore = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"restore","expectedVersion":1}
            """.formatted(UUID.randomUUID(), entity);
        mvc.perform(post(endpoint).header("Authorization", "Bearer " + jwt(other.id))
                .contentType(MediaType.APPLICATION_JSON).content(restore))
            .andExpect(status().isConflict());
        mvc.perform(post(endpoint).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(restore.replace(
                    "\"expectedVersion\":1", "\"expectedVersion\":0")))
            .andExpect(status().isConflict());
        mvc.perform(post(endpoint).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(restore))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(2));

        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer)
                .param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(3))
            .andExpect(jsonPath("$.changes[1].deleted").value(true))
            .andExpect(jsonPath("$.changes[2].deleted").value(false))
            .andExpect(jsonPath("$.changes[2].version").value(2))
            .andExpect(jsonPath("$.changes[2].payload.body").value("Testo integro"));
    }

    @Test
    void latestConflictSnapshotIsOwnerScopedAndIncludesTombstones() throws Exception {
        var a = users.save(new AppUser("latest-a-" + UUID.randomUUID(), "latest-a@example.com", "A"));
        var b = users.save(new AppUser("latest-b-" + UUID.randomUUID(), "latest-b@example.com", "B"));
        String aBearer = "Bearer " + jwt(a.id);
        String bBearer = "Bearer " + jwt(b.id);
        String entity = UUID.randomUUID().toString();
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Online","body":"Contenuto server"}}
            """.formatted(UUID.randomUUID(), entity);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", aBearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk());
        String query = "/api/v1/sync/latest";
        mvc.perform(get(query).header("Authorization", aBearer)
                .param("entityType", "note").param("entityId", entity))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.payload.body").value("Contenuto server"))
            .andExpect(jsonPath("$.version").value(0))
            .andExpect(jsonPath("$.deleted").value(false));
        mvc.perform(get(query).header("Authorization", bBearer)
                .param("entityType", "note").param("entityId", entity))
            .andExpect(status().isNotFound());
        String remove = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"delete","expectedVersion":0}
            """.formatted(UUID.randomUUID(), entity);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", aBearer)
                .contentType(MediaType.APPLICATION_JSON).content(remove))
            .andExpect(status().isOk());
        mvc.perform(get(query).header("Authorization", aBearer)
                .param("entityType", "note").param("entityId", entity))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.deleted").value(true));
    }

    @Test
    void organizedTasksAndListsSyncWithOwnerIsolation() throws Exception {
        var a = users.save(new AppUser("org-a-" + UUID.randomUUID(), "org-a@example.com", "A"));
        var b = users.save(new AppUser("org-b-" + UUID.randomUUID(), "org-b@example.com", "B"));
        String bearerA = "Bearer " + jwt(a.id);
        String bearerB = "Bearer " + jwt(b.id);
        String listId = UUID.randomUUID().toString();
        String taskId = UUID.randomUUID().toString();
        String subId = UUID.randomUUID().toString();
        String createList = """
            {"operationId":"%s","entityId":"%s","entityType":"list",
             "action":"upsert","payload":{"title":"Università"}}
            """.formatted(UUID.randomUUID(), listId);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearerA)
                .contentType(MediaType.APPLICATION_JSON).content(createList))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(0));

        String task = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert",
             "payload":{"title":"Ripassare","completed":false,
                "listId":"%s","priority":3,"tags":["esame","urgente"],
                "subtasks":[{"id":"%s","title":"Capitolo 1","completed":false}]}}
            """.formatted(UUID.randomUUID(), taskId, listId, subId);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearerB)
                .contentType(MediaType.APPLICATION_JSON).content(task))
            .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearerA)
                .contentType(MediaType.APPLICATION_JSON).content(task))
            .andExpect(status().isOk());
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearerA))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(2))
            .andExpect(jsonPath("$.changes[0].entityType").value("list"))
            .andExpect(jsonPath("$.changes[1].payload.listId").value(listId))
            .andExpect(jsonPath("$.changes[1].payload.priority").value(3))
            .andExpect(jsonPath("$.changes[1].payload.tags[0]").value("esame"))
            .andExpect(jsonPath("$.changes[1].payload.subtasks[0].title").value("Capitolo 1"));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearerB))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(0));

        String deleteList = """
            {"operationId":"%s","entityId":"%s","entityType":"list",
             "action":"delete","expectedVersion":0}
            """.formatted(UUID.randomUUID(), listId);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearerA)
                .contentType(MediaType.APPLICATION_JSON).content(deleteList))
            .andExpect(status().isConflict());

        // Moving the task to Inbox does not delete it, then list removal
        // becomes legal. Confirm tombstone is visible in the change log.
        String moved = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Ripassare","completed":false,"listId":null,
                "priority":3,"tags":["esame"],
                "subtasks":[{"id":"%s","title":"Capitolo 1","completed":true}]}}
            """.formatted(UUID.randomUUID(), taskId, subId);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearerA)
                .contentType(MediaType.APPLICATION_JSON).content(moved))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1));
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearerA)
                .contentType(MediaType.APPLICATION_JSON).content(deleteList))
            .andExpect(status().isOk());
        mvc.perform(get("/api/v1/sync/latest").header("Authorization", bearerA)
                .param("entityType", "list").param("entityId", listId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.deleted").value(true));
    }

    @Test
    void modernDueSyncIsPrivateAndOldClientsCannotOverwriteIt() throws Exception {
        var owner = users.save(new AppUser("due-owner-" + UUID.randomUUID(),
            "due-owner@example.com", "Due owner"));
        var stranger = users.save(new AppUser("due-foreign-" + UUID.randomUUID(),
            "due-foreign@example.com", "Foreign"));
        String auth = "Bearer " + jwt(owner.id);
        String foreignAuth = "Bearer " + jwt(stranger.id);
        String entity = UUID.randomUUID().toString();

        mvc.perform(get("/api/v1/capabilities").header("Authorization", auth))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.taskDueSchema").value(1))
            .andExpect(jsonPath("$.requiresExplicitDueForModernTasks").value(true));
        mvc.perform(get("/api/v1/capabilities")).andExpect(status().isUnauthorized());

        String date = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","payload":{"title":"Esame","completed":false,
               "due":{"kind":"date","date":"2026-10-26"}}}
            """.formatted(UUID.randomUUID(), entity);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(date))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));
        // The same operation must stay idempotent.
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(date))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));

        mvc.perform(get("/api/v1/sync/latest").header("Authorization", auth)
            .param("entityType", "task").param("entityId", entity))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.payload.due.kind").value("date"))
            .andExpect(jsonPath("$.payload.due.date").value("2026-10-26"))
            .andExpect(jsonPath("$.payload.dueAt").value(""));
        mvc.perform(get("/api/v1/sync/latest").header("Authorization", foreignAuth)
            .param("entityType", "task").param("entityId", entity))
            .andExpect(status().isNotFound());

        String oldWrite = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Old client edit","dueAt":null}}
            """.formatted(UUID.randomUUID(), entity);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(oldWrite))
            .andExpect(status().is(426))
            .andExpect(jsonPath("$.code").value("CLIENT_UPGRADE_REQUIRED"));
        mvc.perform(put("/api/v1/tasks/{id}", entity).header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"version":0,"title":"Legacy REST edit","completed":false}"""))
            .andExpect(status().is(426))
            .andExpect(jsonPath("$.code").value("CLIENT_UPGRADE_REQUIRED"));

        String timed = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Esame alle due e mezza",
               "due":{"kind":"datetime","date":"2026-10-25","time":"02:30",
                 "timeZone":"Europe/Rome","offsetSeconds":3600,
                 "instant":"2026-10-25T01:30:00Z"}}}
            """.formatted(UUID.randomUUID(), entity);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(timed))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));
        mvc.perform(get("/api/v1/sync/latest").header("Authorization", auth)
            .param("entityType", "task").param("entityId", entity))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.payload.due.kind").value("datetime"))
            .andExpect(jsonPath("$.payload.due.offsetSeconds").value(3600))
            .andExpect(jsonPath("$.payload.due.instant").value("2026-10-25T01:30:00Z"))
            .andExpect(jsonPath("$.payload.dueAt").value("2026-10-25T01:30:00Z"));

        mvc.perform(get("/api/v1/sync/changes").header("Authorization", auth))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(2))
            .andExpect(jsonPath("$.changes[0].payload.due.date").value("2026-10-26"))
            .andExpect(jsonPath("$.changes[1].payload.due.timeZone").value("Europe/Rome"));
    }

    @Test
    void invalidTimedPayloadDoesNotCreateTaskOrChangeLog() throws Exception {
        var user = users.save(new AppUser("invalid-due-" + UUID.randomUUID(),
            "invalid-due@example.com", "No invalid dates"));
        String bearer = "Bearer " + jwt(user.id);
        String bad = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","payload":{"title":"DST gap",
               "due":{"kind":"datetime","date":"2026-03-29","time":"02:30",
                 "timeZone":"Europe/Rome","offsetSeconds":3600,
                 "instant":"2026-03-29T01:30:00Z"}}}
            """.formatted(UUID.randomUUID(), UUID.randomUUID());
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearer)
            .contentType(MediaType.APPLICATION_JSON).content(bad))
            .andExpect(status().isBadRequest());
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(0));

        String old = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","payload":{"title":"Old app","dueAt":"2026-10-24T22:00:00Z"}}
            """.formatted(UUID.randomUUID(), UUID.randomUUID());
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearer)
            .contentType(MediaType.APPLICATION_JSON).content(old))
            .andExpect(status().isOk());
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(1))
            .andExpect(jsonPath("$.changes[0].payload.due.kind").value("legacy"))
            .andExpect(jsonPath("$.changes[0].payload.due.instant").value("2026-10-24T22:00:00Z"));
    }

    @Test
    void inventoryIsReadOnlyOwnerScopedAndContainsNoPayload() throws Exception {
        var a = users.save(new AppUser("inventory-a-" + UUID.randomUUID(),
            "inventory-a@example.com", "Inventory A"));
        var b = users.save(new AppUser("inventory-b-" + UUID.randomUUID(),
            "inventory-b@example.com", "Inventory B"));
        String idA = UUID.randomUUID().toString();
        String idB = UUID.randomUUID().toString();
        String authA = "Bearer " + jwt(a.id);
        String authB = "Bearer " + jwt(b.id);
        String api = "/api/v1/sync/apply";

        String first = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"First","body":"SECRET_ALPHA"}}
            """.formatted(UUID.randomUUID(), idA);
        String second = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Other","body":"SECRET_BETA"}}
            """.formatted(UUID.randomUUID(), idB);
        mvc.perform(post(api).header("Authorization", authA)
            .contentType(MediaType.APPLICATION_JSON).content(first))
            .andExpect(status().isOk());
        mvc.perform(post(api).header("Authorization", authB)
            .contentType(MediaType.APPLICATION_JSON).content(second))
            .andExpect(status().isOk());

        String inventory = "/api/v1/sync/inventory";
        mvc.perform(get(inventory)).andExpect(status().isUnauthorized());
        mvc.perform(get(inventory).header("Authorization", authA))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.complete").value(true))
            .andExpect(jsonPath("$.cursor").isNumber())
            .andExpect(jsonPath("$.items.length()").value(1))
            .andExpect(jsonPath("$.items[0].entityId").value(idA))
            .andExpect(jsonPath("$.items[0].entityType").value("note"))
            .andExpect(jsonPath("$.items[0].version").value(0))
            .andExpect(jsonPath("$.items[0].deleted").value(false))
            .andExpect(jsonPath("$.items[0].payload").doesNotExist())
            .andExpect(content().string(
                org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("SECRET_ALPHA"))))
            .andExpect(content().string(
                org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("SECRET_BETA"))));
        mvc.perform(get(inventory).header("Authorization", authB))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.items.length()").value(1))
            .andExpect(jsonPath("$.items[0].entityId").value(idB));
        // Repeated inventory fetch does not create changes or acknowledgments.
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", authA))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(1));
    }


    @Test
    void reconciliationCheckIsReadOnlySameOwnerAndDetectsStaleVersions() throws Exception {
        var owner = users.save(new AppUser("reconciliation-owner-" + UUID.randomUUID(),
            "preflight-owner@example.com", "Owner"));
        var foreign = users.save(new AppUser("reconciliation-foreign-" + UUID.randomUUID(),
            "preflight-foreign@example.com", "Foreign"));
        String bearer = "Bearer " + jwt(owner.id);
        String otherBearer = "Bearer " + jwt(foreign.id);
        String entity = UUID.randomUUID().toString();
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"PRIVATE-OWNER-TITLE",
             "body":"PRIVATE-OWNER-BODY"}}
            """.formatted(UUID.randomUUID(), entity);
        String apply = "/api/v1/sync/apply";
        long first = mapper.readTree(mvc.perform(post(apply)
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andReturn()
            .getResponse().getContentAsString()).path("changeId").asLong();

        String endpoint = "/api/v1/sync/reconciliation/check";
        String expected = """
            {"expectedCursor":%d,"items":[
              {"entityType":"note","entityId":"%s",
               "changeId":%d,"version":0,"deleted":false}
            ]}
            """.formatted(first, entity, first);
        mvc.perform(post(endpoint))
            .andExpect(status().isUnauthorized());
        mvc.perform(post(endpoint).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(expected))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.cursor").value(first))
            .andExpect(jsonPath("$.cursorMatches").value(true))
            .andExpect(jsonPath("$.consistent").value(true))
            .andExpect(jsonPath("$.items.length()").value(1))
            .andExpect(jsonPath("$.items[0].matches").value(true))
            .andExpect(jsonPath("$.items[0].version").value(0))
            .andExpect(jsonPath("$.items[0].payload").doesNotExist())
            .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                .content().string(org.hamcrest.Matchers.not(
                    org.hamcrest.Matchers.containsString("PRIVATE-OWNER-BODY"))));

        // A second account must not learn the first account's revisions.
        mvc.perform(post(endpoint).header("Authorization", otherBearer)
                .contentType(MediaType.APPLICATION_JSON).content(expected))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.cursor").value(0))
            .andExpect(jsonPath("$.cursorMatches").value(false))
            .andExpect(jsonPath("$.consistent").value(false))
            .andExpect(jsonPath("$.items[0].matches").value(false))
            .andExpect(jsonPath("$.items[0].changeId").doesNotExist());

        String update = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","expectedVersion":0,
             "expectedAccountCursor":%d,
             "payload":{"title":"Edited","body":"Changed"}}
            """.formatted(UUID.randomUUID(), entity, first);
        mvc.perform(post(apply).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(update))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1));

        // No preflight snapshot is a lease: old revisions now mismatch.
        mvc.perform(post(endpoint).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(expected))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.consistent").value(false))
            .andExpect(jsonPath("$.cursorMatches").value(false))
            .andExpect(jsonPath("$.items[0].matches").value(false));

        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(2));
    }

    @Test
    void cursorCasPreventsStaleWritesWithoutBreakingLegacyClientsOrIdempotency()
            throws Exception {
        var a = users.save(new AppUser("guarded-a-" + UUID.randomUUID(),
            "guarded-a@example.com", "Guarded A"));
        var b = users.save(new AppUser("guarded-b-" + UUID.randomUUID(),
            "guarded-b@example.com", "Guarded B"));
        String bearer = "Bearer " + jwt(a.id);
        String bBearer = "Bearer " + jwt(b.id);
        String entity = UUID.randomUUID().toString();
        String apply = "/api/v1/sync/apply";

        // Existing devices continue to work without expectedAccountCursor.
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Initial","body":"Original"}}
            """.formatted(UUID.randomUUID(), entity);
        long cursor = mapper.readTree(mvc.perform(post(apply)
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andReturn()
            .getResponse().getContentAsString()).path("changeId").asLong();

        // Interleaved global change IDs from a foreign owner must not
        // invalidate A's own owner-scoped cursor precondition.
        String foreign = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Foreign","body":"Hidden"}}
            """.formatted(UUID.randomUUID(), UUID.randomUUID());
        mvc.perform(post(apply).header("Authorization", bBearer)
                .contentType(MediaType.APPLICATION_JSON).content(foreign))
            .andExpect(status().isOk());

        String guardedOperation = UUID.randomUUID().toString();
        String guarded = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","expectedVersion":0,"expectedAccountCursor":%d,
             "payload":{"title":"Guarded","body":"Preserved"}}
            """.formatted(guardedOperation, entity, cursor);
        long advanced = mapper.readTree(mvc.perform(post(apply)
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(guarded))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1)).andReturn()
            .getResponse().getContentAsString()).path("changeId").asLong();
        // Correct idempotent resend must still succeed even after cursor advanced.
        mvc.perform(post(apply).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(guarded))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changeId").value(advanced));

        String stale = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","expectedVersion":1,"expectedAccountCursor":%d,
             "payload":{"title":"Do not overwrite","body":"Too old"}}
            """.formatted(UUID.randomUUID(), entity, cursor);
        mvc.perform(post(apply).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(stale))
            .andExpect(status().isConflict());
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(2))
            .andExpect(jsonPath("$.changes[1].payload.title").value("Guarded"));

        String negative = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"delete","expectedVersion":1,"expectedAccountCursor":-1}
            """.formatted(UUID.randomUUID(), entity);
        mvc.perform(post(apply).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(negative))
            .andExpect(status().isBadRequest());
    }

    @Test
    void preflightRejectsInvalidAndDuplicateRecordsAndChecksMissingEntities()
            throws Exception {
        var user = users.save(new AppUser("reconciliation-invalid-" + UUID.randomUUID(),
            "reconciliation-invalid@example.com", "Check validation"));
        String bearer = "Bearer " + jwt(user.id);
        String endpoint = "/api/v1/sync/reconciliation/check";
        String unknown = UUID.randomUUID().toString();
        String absent = """
            {"expectedCursor":0,"items":[{"entityType":"note",
             "entityId":"%s","changeId":null,
             "version":null,"deleted":null}]}
            """.formatted(unknown);
        mvc.perform(post(endpoint).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(absent))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.consistent").value(true))
            .andExpect(jsonPath("$.cursor").value(0))
            .andExpect(jsonPath("$.items[0].matches").value(true));
        for (String bad : List.of(
            "{\"expectedCursor\":-1,\"items\":[{\"entityType\":\"note\"," +
                "\"entityId\":\"" + unknown + "\"}]}",
            "{\"expectedCursor\":0,\"items\":[]}",
            "{\"expectedCursor\":0,\"items\":[{\"entityType\":\"other\"," +
                "\"entityId\":\"" + unknown + "\"}]}",
            "{\"expectedCursor\":0,\"items\":[{\"entityType\":\"note\"," +
                "\"entityId\":\"" + unknown + "\",\"changeId\":4}]}",
            "{\"expectedCursor\":0,\"items\":[{\"entityType\":\"note\"," +
                "\"entityId\":\"" + unknown + "\",\"version\":0}]}",
            "{\"expectedCursor\":0,\"items\":[" +
                "{\"entityType\":\"note\",\"entityId\":\"" + unknown + "\"}," +
                "{\"entityType\":\"note\",\"entityId\":\"" + unknown + "\"}]}"
        )) {
            mvc.perform(post(endpoint).header("Authorization", bearer)
                    .contentType(MediaType.APPLICATION_JSON).content(bad))
                .andExpect(status().isBadRequest());
        }
    }

    @Test
    void racingAccountCursorCasAllowsOnlyOneOfTwoConflictingWrites()
            throws Exception {
        var user = users.save(new AppUser("cursor-race-" + UUID.randomUUID(),
            "cursor-race@example.com", "CAS race"));
        String bearer = "Bearer " + jwt(user.id);
        String entity = UUID.randomUUID().toString();
        String apply = "/api/v1/sync/apply";
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Initial","body":"B"}}
            """.formatted(UUID.randomUUID(), entity);
        long cursor = mapper.readTree(mvc.perform(post(apply)
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andReturn()
            .getResponse().getContentAsString()).path("changeId").asLong();
        String first = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","expectedVersion":0,"expectedAccountCursor":%d,
             "payload":{"title":"Concurrent A","body":"A"}}
            """.formatted(UUID.randomUUID(), entity, cursor);
        String second = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","expectedVersion":0,"expectedAccountCursor":%d,
             "payload":{"title":"Concurrent B","body":"B"}}
            """.formatted(UUID.randomUUID(), entity, cursor);
        var pool = Executors.newFixedThreadPool(2);
        try {
            CountDownLatch begin = new CountDownLatch(1);
            Future<Integer> one = pool.submit(() -> {
                begin.await();
                return mvc.perform(post(apply).header("Authorization", bearer)
                    .contentType(MediaType.APPLICATION_JSON).content(first))
                    .andReturn().getResponse().getStatus();
            });
            Future<Integer> two = pool.submit(() -> {
                begin.await();
                return mvc.perform(post(apply).header("Authorization", bearer)
                    .contentType(MediaType.APPLICATION_JSON).content(second))
                    .andReturn().getResponse().getStatus();
            });
            begin.countDown();
            int aStatus = one.get(30, TimeUnit.SECONDS);
            int bStatus = two.get(30, TimeUnit.SECONDS);
            org.junit.jupiter.api.Assertions.assertEquals(
                List.of(200, 409), java.util.stream.Stream.of(aStatus, bStatus)
                    .sorted().toList());
        } finally {
            pool.shutdownNow();
        }
        mvc.perform(get("/api/v1/sync/changes")
                .header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(2));
    }


    @Test
    void preflightRejectsUntrackedRowsMissingFromSyncLedgerWithoutLeakingData()
            throws Exception {
        var owner = users.save(new AppUser("legacy-ledger-owner-" + UUID.randomUUID(),
            "legacy-ledger-owner@example.com", "Legacy A"));
        var other = users.save(new AppUser("legacy-ledger-other-" + UUID.randomUUID(),
            "legacy-ledger-other@example.com", "Legacy B"));
        String bearer = "Bearer " + jwt(owner.id);
        String otherBearer = "Bearer " + jwt(other.id);
        // Simulate a data writer bypassing the synchronized REST services.
        // Normal /notes mutations now append events atomically.
        UUID rawId = UUID.randomUUID();
        jdbc.update("INSERT INTO note (id,owner_id,title,body) VALUES (?,?,?,?)",
            rawId, owner.id, "Untracked sensitive title", "Untracked body");
        String noteId = rawId.toString();
        String expectedAbsent = """
            {"expectedCursor":0,"items":[
              {"entityType":"note","entityId":"%s",
               "changeId":null,"version":null,"deleted":null}
            ]}
            """.formatted(noteId);
        // Without the cross-store check the absent ledger would falsely
        // report a clean preflight despite an existing legacy note.
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(expectedAbsent))
            .andExpect(status().isConflict());
        // The other owner cannot see this row, even through the preflight.
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", otherBearer)
                .contentType(MediaType.APPLICATION_JSON).content(expectedAbsent))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.consistent").value(true))
            .andExpect(jsonPath("$.items[0].changeId").doesNotExist());
        mvc.perform(get("/api/v1/sync/changes")
                .header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(0));
    }

    @Test
    void preflightRejectsUntrackedSqlEditsAfterSyncedNotes()
            throws Exception {
        var user = users.save(new AppUser("legacy-edit-owner-" + UUID.randomUUID(),
            "legacy-edit-owner@example.com", "Legacy edits"));
        String bearer = "Bearer " + jwt(user.id);
        String noteId = UUID.randomUUID().toString();
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Synced","body":"Original"}}
            """.formatted(UUID.randomUUID(), noteId);
        long cursor = mapper.readTree(mvc.perform(post("/api/v1/sync/apply")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andReturn()
            .getResponse().getContentAsString()).path("changeId").asLong();
        String expected = """
            {"expectedCursor":%d,"items":[
              {"entityType":"note","entityId":"%s",
               "changeId":%d,"version":0,"deleted":false}
            ]}
            """.formatted(cursor, noteId, cursor);
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(expected))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.consistent").value(true));

        // Direct SQL bypass (NOT the normal REST API) changes the row without
        // creating a ledger event. The preflight must reject this corruption.
        jdbc.update("UPDATE note SET title=?, body=?, version=version+1 " +
            "WHERE id=? AND owner_id=?", "Untracked edit", "Sensitive new body",
            UUID.fromString(noteId), user.id);
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(expected))
            .andExpect(status().isConflict());
        mvc.perform(get("/api/v1/sync/changes")
                .header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(1))
            .andExpect(jsonPath("$.changes[0].version").value(0));
    }

    @Test
    void preflightRejectsUntrackedSqlTombstoneWithoutSyncEvent()
            throws Exception {
        var user = users.save(new AppUser("legacy-delete-owner-" + UUID.randomUUID(),
            "legacy-delete-owner@example.com", "Legacy deletion"));
        String bearer = "Bearer " + jwt(user.id);
        String entity = UUID.randomUUID().toString();
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Synced","body":"Protected"}}
            """.formatted(UUID.randomUUID(), entity);
        long cursor = mapper.readTree(mvc.perform(post("/api/v1/sync/apply")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andReturn()
            .getResponse().getContentAsString()).path("changeId").asLong();
        jdbc.update("UPDATE note SET deleted_at=now(), version=version+1 " +
            "WHERE id=? AND owner_id=?", UUID.fromString(entity), user.id);
        String check = """
            {"expectedCursor":%d,"items":[
              {"entityType":"note","entityId":"%s",
               "changeId":%d,"version":0,"deleted":false}
            ]}
            """.formatted(cursor, entity, cursor);
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(check))
            .andExpect(status().isConflict());
    }


    @Test
    void ownerWidePreflightRejectsUnlistedLegacyRowEvenWhenQueriedItemMatches()
            throws Exception {
        var owner = users.save(new AppUser("account-scan-" + UUID.randomUUID(),
            "account-scan@example.com", "Owner"));
        var foreign = users.save(new AppUser("account-scan-other-" + UUID.randomUUID(),
            "account-scan-other@example.com", "Other"));
        String bearer = "Bearer " + jwt(owner.id);
        String foreignBearer = "Bearer " + jwt(foreign.id);
        String entity = UUID.randomUUID().toString();
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Synced","body":"One"}}
            """.formatted(UUID.randomUUID(), entity);
        long cursor = mapper.readTree(mvc.perform(post("/api/v1/sync/apply")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andReturn()
            .getResponse().getContentAsString()).path("changeId").asLong();
        String check = """
            {"expectedCursor":%d,"items":[{"entityType":"note",
              "entityId":"%s","changeId":%d,"version":0,"deleted":false}]}
            """.formatted(cursor, entity, cursor);
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(check))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.consistent").value(true));

        // A foreign owner's untracked SQL row must not affect this owner.
        jdbc.update("INSERT INTO note (id,owner_id,title,body) VALUES (?,?,?,?)",
            UUID.randomUUID(), foreign.id, "Foreign private", "Hidden");
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(check))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.consistent").value(true));

        // A directly inserted, unlisted note is invisible in the ledger.
        jdbc.update("INSERT INTO note (id,owner_id,title,body) VALUES (?,?,?,?)",
            UUID.randomUUID(), owner.id, "Untracked private", "Hidden");
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(check))
            .andExpect(status().isConflict());
        mvc.perform(get("/api/v1/sync/changes")
                .header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(1));
    }

    @Test
    void ownerWidePreflightRejectsUnlistedLegacyTaskAndMissingActiveNote()
            throws Exception {
        var owner = users.save(new AppUser("scan-task-" + UUID.randomUUID(),
            "scan-task@example.com", "Task check"));
        String bearer = "Bearer " + jwt(owner.id);
        String entity = UUID.randomUUID().toString();
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","payload":{"title":"Tracked","body":"Contents"}}
            """.formatted(UUID.randomUUID(), entity);
        long cursor = mapper.readTree(mvc.perform(post("/api/v1/sync/apply")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andReturn()
            .getResponse().getContentAsString()).path("changeId").asLong();
        String check = """
            {"expectedCursor":%d,"items":[{"entityType":"note",
              "entityId":"%s","changeId":%d,"version":0,"deleted":false}]}
            """.formatted(cursor, entity, cursor);

        // A direct SQL task bypass is not referenced in the requested notes.
        UUID taskId = UUID.randomUUID();
        jdbc.update("INSERT INTO task (id,owner_id,title) VALUES (?,?,?)",
            taskId, owner.id, "Untracked task");
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(check))
            .andExpect(status().isConflict());
        jdbc.update("DELETE FROM task WHERE id = ? AND owner_id = ?", taskId, owner.id);
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(check))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.consistent").value(true));

        // An active sync record without a physical note is also unsafe.
        jdbc.update("DELETE FROM note WHERE id = ? AND owner_id = ?",
            UUID.fromString(entity), owner.id);
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(check))
            .andExpect(status().isConflict());
    }

    @Test
    void syntheticTombstoneWithoutPhysicalEntityRemainsRepresentable()
            throws Exception {
        var owner = users.save(new AppUser("scan-tombstone-" + UUID.randomUUID(),
            "scan-tombstone@example.com", "Tombstone check"));
        String bearer = "Bearer " + jwt(owner.id);
        String entity = UUID.randomUUID().toString();
        String remove = """
            {"operationId":"%s","entityId":"%s",
             "entityType":"note","action":"delete","expectedVersion":null}
            """.formatted(UUID.randomUUID(), entity);
        long cursor = mapper.readTree(mvc.perform(post("/api/v1/sync/apply")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(remove))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(0))
            .andReturn().getResponse().getContentAsString())
            .path("changeId").asLong();
        String check = """
            {"expectedCursor":%d,"items":[{"entityType":"note",
              "entityId":"%s","changeId":%d,"version":0,"deleted":true}]}
            """.formatted(cursor, entity, cursor);
        mvc.perform(post("/api/v1/sync/reconciliation/check")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(check))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.consistent").value(true));
    }


    @Test
    void legacyNoteCreateUpdateDeleteUsesSameOwnerLockedSyncLedger()
            throws Exception {
        var user = users.save(new AppUser("legacy-note-bridge-" + UUID.randomUUID(),
            "legacy-note-bridge@example.com", "Bridge"));
        String bearer = "Bearer " + jwt(user.id);
        String created = mvc.perform(post("/api/v1/notes")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\":\"Created by REST\",\"body\":\"Private body\"}"))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.version").value(0))
            .andReturn().getResponse().getContentAsString();
        String id = mapper.readTree(created).path("id").asText();
        long firstCursor = mapper.readTree(mvc.perform(get("/api/v1/sync/changes")
                .header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(1))
            .andExpect(jsonPath("$.changes[0].entityType").value("note"))
            .andExpect(jsonPath("$.changes[0].entityId").value(id))
            .andExpect(jsonPath("$.changes[0].payload.body").value("Private body"))
            .andReturn().getResponse().getContentAsString())
            .path("nextCursor").asLong();

        mvc.perform(put("/api/v1/notes/" + id)
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"version\":0,\"title\":\"Renamed\",\"body\":\"Updated\"}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1));
        mvc.perform(get("/api/v1/sync/changes")
                .header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(2))
            .andExpect(jsonPath("$.changes[1].version").value(1))
            .andExpect(jsonPath("$.changes[1].payload.title").value("Renamed"));

        // Both REST and sync/apply participate in the same account cursor.
        String stale = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","expectedVersion":1,"expectedAccountCursor":%d,
             "payload":{"title":"Stale","body":"Must not overwrite"}}
            """.formatted(UUID.randomUUID(), id, firstCursor);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(stale))
            .andExpect(status().isConflict());
        mvc.perform(delete("/api/v1/notes/" + id)
                .header("Authorization", bearer).param("version", "1"))
            .andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/sync/changes")
                .header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(3))
            .andExpect(jsonPath("$.changes[2].deleted").value(true))
            .andExpect(jsonPath("$.changes[2].version").value(2));
        mvc.perform(get("/api/v1/notes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(0));
        mvc.perform(put("/api/v1/notes/" + id)
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"version\":2,\"title\":\"Resurrect\",\"body\":\"No\"}"))
            .andExpect(status().isNotFound());
    }

    @Test
    void legacyTaskCrudAndCompletionPublishCanonicalEvents()
            throws Exception {
        var user = users.save(new AppUser("legacy-task-bridge-" + UUID.randomUUID(),
            "legacy-task-bridge@example.com", "Task bridge"));
        String bearer = "Bearer " + jwt(user.id);
        String created = mvc.perform(post("/api/v1/tasks")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\":\"Legacy task\",\"description\":\"Details\"}"))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.version").value(0))
            .andReturn().getResponse().getContentAsString();
        String id = mapper.readTree(created).path("id").asText();
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(1))
            .andExpect(jsonPath("$.changes[0].payload.due.kind").value("none"))
            .andExpect(jsonPath("$.changes[0].payload.timeBlocks.length()").value(0));

        mvc.perform(put("/api/v1/tasks/" + id)
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"version\":0,\"title\":\"Updated\",\"description\":\"Details 2\",\"completed\":false}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1));
        mvc.perform(patch("/api/v1/tasks/" + id + "/completion")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"completed\":true}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(2));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(3))
            .andExpect(jsonPath("$.changes[2].payload.title").value("Updated"))
            .andExpect(jsonPath("$.changes[2].payload.completed").value(true))
            .andExpect(jsonPath("$.changes[2].payload.recurrence.kind").value("none"));

        mvc.perform(delete("/api/v1/tasks/" + id)
                .header("Authorization", bearer))
            .andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(4))
            .andExpect(jsonPath("$.changes[3].deleted").value(true));
        mvc.perform(get("/api/v1/tasks").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void legacyCompletionPreservesModernCivilDueAndRecurrence()
            throws Exception {
        var user = users.save(new AppUser("modern-task-completion-" + UUID.randomUUID(),
            "modern-task-completion@example.com", "Modern"));
        String bearer = "Bearer " + jwt(user.id);
        String id = UUID.randomUUID().toString();
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","payload":{
               "title":"Modern","description":"Preserve all",
               "due":{"kind":"date","date":"2026-11-20"},
               "completed":false,"timeBlocks":[],
               "recurrence":{"kind":"weekly","interval":2},
               "tags":["Focus"],"priority":2,"subtasks":[]
             }}
            """.formatted(UUID.randomUUID(), id);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(0));
        mvc.perform(patch("/api/v1/tasks/" + id + "/completion")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"completed\":true}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(2))
            .andExpect(jsonPath("$.changes[1].payload.due.kind").value("date"))
            .andExpect(jsonPath("$.changes[1].payload.due.date").value("2026-11-20"))
            .andExpect(jsonPath("$.changes[1].payload.completed").value(true))
            .andExpect(jsonPath("$.changes[1].payload.recurrence.kind").value("weekly"))
            .andExpect(jsonPath("$.changes[1].payload.recurrence.interval").value(2))
            .andExpect(jsonPath("$.changes[1].payload.priority").value(2))
            .andExpect(jsonPath("$.changes[1].payload.tags[0]").value("Focus"));
        // Old full-task editor cannot safely rewrite a modern civil due.
        mvc.perform(put("/api/v1/tasks/" + id)
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"version\":1,\"title\":\"Old client\",\"completed\":false}"))
            .andExpect(status().isUpgradeRequired());
    }

    @Test
    void concurrentLegacyRestAndSyncWritesCannotBothOverwriteOneNote()
            throws Exception {
        var user = users.save(new AppUser("race-legacy-sync-" + UUID.randomUUID(),
            "race-legacy-sync@example.com", "Race"));
        String bearer = "Bearer " + jwt(user.id);
        String created = mvc.perform(post("/api/v1/notes")
                .header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\":\"Original\",\"body\":\"B\"}"))
            .andExpect(status().isCreated())
            .andReturn().getResponse().getContentAsString();
        String id = mapper.readTree(created).path("id").asText();
        String sync = """
            {"operationId":"%s","entityId":"%s","entityType":"note",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Sync winner","body":"S"}}
            """.formatted(UUID.randomUUID(), id);
        var pool = Executors.newFixedThreadPool(2);
        try {
            CountDownLatch gate = new CountDownLatch(1);
            Future<Integer> oldRest = pool.submit(() -> {
                gate.await();
                return mvc.perform(put("/api/v1/notes/" + id)
                    .header("Authorization", bearer)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"version\":0,\"title\":\"REST winner\",\"body\":\"R\"}"))
                    .andReturn().getResponse().getStatus();
            });
            Future<Integer> syncApply = pool.submit(() -> {
                gate.await();
                return mvc.perform(post("/api/v1/sync/apply")
                    .header("Authorization", bearer)
                    .contentType(MediaType.APPLICATION_JSON).content(sync))
                    .andReturn().getResponse().getStatus();
            });
            gate.countDown();
            org.junit.jupiter.api.Assertions.assertEquals(List.of(200, 409),
                java.util.stream.Stream.of(oldRest.get(30, TimeUnit.SECONDS),
                    syncApply.get(30, TimeUnit.SECONDS)).sorted().toList());
        } finally {
            pool.shutdownNow();
        }
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", bearer))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(2))
            .andExpect(jsonPath("$.changes[1].version").value(1));
    }

}
