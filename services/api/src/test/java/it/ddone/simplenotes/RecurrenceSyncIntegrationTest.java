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
class RecurrenceSyncIntegrationTest {
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

    @Test void dueAndRecurrenceSurviveSyncWhileOldClientCannotEraseRule()
        throws Exception {
        var owner = users.save(new AppUser("rec-" + UUID.randomUUID(),
            "rec@example.com", "Rec"));
        var auth = jwt(owner.id);
        var id = UUID.randomUUID().toString();
        mvc.perform(get("/api/v1/capabilities").header("Authorization", auth))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.recurrenceSchema").value(1));

        var initial = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","payload":{"title":"Ripetizione",
              "due":{"kind":"date","date":"2026-10-25"},
              "timeBlocks":[],
              "recurrence":{"kind":"weekly","interval":2}}}
            """.formatted(UUID.randomUUID(), id);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(initial))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", auth)
            .param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes[0].payload.recurrence.kind").value("weekly"))
            .andExpect(jsonPath("$.changes[0].payload.recurrence.interval").value(2))
            .andExpect(jsonPath("$.changes[0].payload.due.date").value("2026-10-25"));

        var old = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Vecchio",
              "due":{"kind":"date","date":"2026-10-25"},
              "timeBlocks":[]}}
            """.formatted(UUID.randomUUID(), id);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(old))
            .andExpect(status().isUpgradeRequired());

        var newTask = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":0,
             "payload":{"title":"Ripetizione",
              "due":{"kind":"date","date":"2026-11-08"},
              "timeBlocks":[],
              "recurrence":{"kind":"weekly","interval":2},
              "completed":false}}
            """.formatted(UUID.randomUUID(), id);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(newTask))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", auth)
            .param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes[1].payload.due.date").value("2026-11-08"))
            .andExpect(jsonPath("$.changes[1].payload.recurrence.kind").value("weekly"));

        var invalid = """
            {"operationId":"%s","entityId":"%s","entityType":"task",
             "action":"upsert","expectedVersion":1,
             "payload":{"title":"Invalid", "due":{"kind":"none"},
              "recurrence":{"kind":"daily","interval":1},"timeBlocks":[]}}
            """.formatted(UUID.randomUUID(), id);
        mvc.perform(post("/api/v1/sync/apply").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(invalid))
            .andExpect(status().isBadRequest());
    }
}
