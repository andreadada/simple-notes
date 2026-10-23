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

}
