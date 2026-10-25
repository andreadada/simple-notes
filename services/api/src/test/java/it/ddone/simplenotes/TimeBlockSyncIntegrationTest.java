package it.ddone.simplenotes;

import it.ddone.simplenotes.user.AppUser;
import it.ddone.simplenotes.user.AppUserRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
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
class TimeBlockSyncIntegrationTest {
    @Container static final PostgreSQLContainer<?> pg =
        new PostgreSQLContainer<>("postgres:17-alpine");
    @DynamicPropertySource static void properties(DynamicPropertyRegistry p) {
        p.add("spring.datasource.url", pg::getJdbcUrl);
        p.add("spring.datasource.username", pg::getUsername);
        p.add("spring.datasource.password", pg::getPassword);
        p.add("app.google.client-ids", () -> "test-google-client");
        p.add("app.jwt.secret-base64", () -> "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVoxMjM0NTY=");
    }
    @Autowired MockMvc mvc;
    @Autowired AppUserRepository users;
    @Autowired JwtEncoder encoder;

    private String jwt(UUID owner) {
        var now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("simple-notes-api")
            .audience(List.of("simple-notes")).subject(owner.toString())
            .issuedAt(now).expiresAt(now.plusSeconds(600)).build();
        return "Bearer " + encoder.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    @Test void timeBlockLifecycleIsVersionedAndPreservesDueDate() throws Exception {
        var owner = users.save(new AppUser("p1-block-" + UUID.randomUUID(),
            "p1@example.com", "P1"));
        String token = jwt(owner.id);
        String id = UUID.randomUUID().toString();
        mvc.perform(get("/api/v1/capabilities").header("Authorization", token))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.timeBlockSchema").value(1));

        String start = "2026-10-26T08:00:00Z";
        String end = "2026-10-26T09:30:00Z";
        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","payload":{"title":"Studiare",
               "due":{"kind":"date","date":"2026-10-28"},
               "timeBlock":{"kind":"range","start":"%s","end":"%s",
                            "timeZone":"Europe/Rome"},
               "completed":false}}
            """.formatted(UUID.randomUUID(), id, start, end);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));

        mvc.perform(get("/api/v1/sync/changes").header("Authorization", token)
            .param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes[0].payload.timeBlock.kind").value("range"))
            .andExpect(jsonPath("$.changes[0].payload.due.date").value("2026-10-28"))
            .andExpect(jsonPath("$.changes[0].payload.timeBlock.timeZone").value("Europe/Rome"));

        // An old client must not erase this interval by merely renaming a task.
        String oldEdit = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Rinominata","due":{"kind":"date","date":"2026-10-28"}}}
            """.formatted(UUID.randomUUID(), id);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(oldEdit))
            .andExpect(status().isUpgradeRequired());

        String clear = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Studiare",
               "due":{"kind":"date","date":"2026-10-28"},
               "timeBlock":{"kind":"none"},"completed":false}}
            """.formatted(UUID.randomUUID(), id);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(clear))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", token)
            .param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes[1].payload.timeBlock.kind").value("none"))
            .andExpect(jsonPath("$.changes[1].payload.due.date").value("2026-10-28"));
    }

    @Test void rejectsInvalidRangesWithoutCreatingTask() throws Exception {
        var owner = users.save(new AppUser("invalid-block-" + UUID.randomUUID(),
            "p1-invalid@example.com", "P1"));
        String token = jwt(owner.id);
        for (String badBlock : List.of(
            "{\"kind\":\"range\",\"start\":\"2026-10-26T09:00:00Z\","
               + "\"end\":\"2026-10-26T08:00:00Z\",\"timeZone\":\"Europe/Rome\"}",
            "{\"kind\":\"range\",\"start\":\"2026-10-26T08:00:00Z\","
               + "\"end\":\"2026-10-28T08:00:00Z\",\"timeZone\":\"Europe/Rome\"}",
            "{\"kind\":\"range\",\"start\":\"2026-10-26T08:00:00Z\","
               + "\"end\":\"2026-10-26T09:00:00Z\",\"timeZone\":\"Bad/Zone\"}",
            "{\"kind\":\"range\",\"start\":\"2026-10-26T08:00:30Z\","
               + "\"end\":\"2026-10-26T09:00:00Z\",\"timeZone\":\"Europe/Rome\"}"
        )) {
            String request = """
                {"operationId":"%s","entityId":"%s","entityType":"task",
                 "action":"upsert","payload":{"title":"Reject",
                  "timeBlock":%s}}
                """.formatted(UUID.randomUUID(), UUID.randomUUID(), badBlock);
            mvc.perform(post("/api/v1/sync/apply").header("Authorization", token)
                .contentType(MediaType.APPLICATION_JSON).content(request))
                .andExpect(status().isBadRequest());
        }
    }

    @Test void multipleBlocksSurviveSyncAndLegacyClientsCannotEraseThem()
        throws Exception {
        var owner = users.save(new AppUser("multi-" + UUID.randomUUID(),
            "multi@example.com", "Multi"));
        String auth = jwt(owner.id);
        String task = UUID.randomUUID().toString();
        String first = UUID.randomUUID().toString();
        String second = UUID.randomUUID().toString();
        mvc.perform(get("/api/v1/capabilities").header("Authorization", auth))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.timeBlocksSchema").value(1));

        String create = """
            {"operationId":"%s","entityId":"%s","entityType":"task","action":"upsert",
             "payload":{"title":"Sessioni di studio",
              "due":{"kind":"date","date":"2026-11-02"},
              "timeBlock":{"kind":"range","start":"2026-11-01T08:00:00Z",
                "end":"2026-11-01T09:00:00Z","timeZone":"Europe/Rome"},
              "timeBlocks":[
                {"id":"%s","start":"2026-11-01T08:00:00Z",
                 "end":"2026-11-01T09:00:00Z","timeZone":"Europe/Rome"},
                {"id":"%s","start":"2026-11-01T12:00:00Z",
                 "end":"2026-11-01T13:00:00Z","timeZone":"Europe/Rome"}]}}
            """.formatted(UUID.randomUUID(), task, first, second);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(create))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));

        mvc.perform(get("/api/v1/sync/changes").header("Authorization", auth)
            .param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes[0].payload.timeBlocks.length()").value(2))
            .andExpect(jsonPath("$.changes[0].payload.timeBlocks[0].id").value(first))
            .andExpect(jsonPath("$.changes[0].payload.timeBlocks[1].id").value(second))
            .andExpect(jsonPath("$.changes[0].payload.due.date").value("2026-11-02"));

        // V8 client can see the mirror but cannot destroy the second interval.
        String legacyEdit = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Vecchio client",
              "timeBlock":{"kind":"range","start":"2026-11-01T08:00:00Z",
                "end":"2026-11-01T09:00:00Z","timeZone":"Europe/Rome"}}}
            """.formatted(UUID.randomUUID(), task);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(legacyEdit))
            .andExpect(status().isUpgradeRequired());

        // New app edits one interval and preserves the other and the deadline.
        String update = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Sessioni di studio",
              "due":{"kind":"date","date":"2026-11-02"},
              "timeBlocks":[
                {"id":"%s","start":"2026-11-01T08:00:00Z",
                 "end":"2026-11-01T09:00:00Z","timeZone":"Europe/Rome"},
                {"id":"%s","start":"2026-11-01T13:00:00Z",
                 "end":"2026-11-01T14:00:00Z","timeZone":"Europe/Rome"}]}}
            """.formatted(UUID.randomUUID(), task, first, second);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(update))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", auth)
            .param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes[1].payload.timeBlocks[0].id").value(first))
            .andExpect(jsonPath("$.changes[1].payload.timeBlocks[1].id").value(second))
            .andExpect(jsonPath("$.changes[1].payload.timeBlocks[1].start")
                .value("2026-11-01T13:00:00Z"))
            .andExpect(jsonPath("$.changes[1].payload.due.date").value("2026-11-02"));

        // Duplicate slot IDs are invalid: failed request must not change task.
        String bad = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":1,
             "payload":{"title":"No",
              "due":{"kind":"date","date":"2026-11-02"},
              "timeBlocks":[
                {"id":"%s","start":"2026-11-01T08:00:00Z",
                 "end":"2026-11-01T09:00:00Z","timeZone":"Europe/Rome"},
                {"id":"%s","start":"2026-11-02T08:00:00Z",
                 "end":"2026-11-02T09:00:00Z","timeZone":"Europe/Rome"}]}}
            """.formatted(UUID.randomUUID(), task, first, first);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(bad))
            .andExpect(status().isBadRequest());
    }

}
