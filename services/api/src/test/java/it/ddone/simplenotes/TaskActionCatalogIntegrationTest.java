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
class TaskActionCatalogIntegrationTest {
    @Container
    static final PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:17-alpine");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", postgres::getJdbcUrl);
        r.add("spring.datasource.username", postgres::getUsername);
        r.add("spring.datasource.password", postgres::getPassword);
        r.add("app.google.client-ids", () -> "test-google-client");
        r.add("app.jwt.secret-base64",
            () -> "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVoxMjM0NTY=");
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

    private AppUser user() {
        return users.save(new AppUser("rule-" + UUID.randomUUID(),
            "test@example.com", "Rules"));
    }

    private static final String PATH = "/api/v1/automations/task-actions";
    private static final String CATALOG = """
        {"schema":1,"rules":[{"id":"action-abc123","trigger":"created",
        "action":"tag","value":"Studio","titleContains":"esame",
        "enabled":true}]}
        """;

    @Test
    void requiresJwtAndNewAccountStartsAtRevisionZero() throws Exception {
        mvc.perform(get(PATH)).andExpect(status().isUnauthorized());
        mvc.perform(put(PATH).contentType(MediaType.APPLICATION_JSON)
            .content("{\"expectedVersion\":0,\"catalog\":{\"schema\":1,\"rules\":[]}}"))
            .andExpect(status().isUnauthorized());
        var user = user();
        mvc.perform(get(PATH).header("Authorization", jwt(user.id)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(0))
            .andExpect(jsonPath("$.catalog.schema").value(1))
            .andExpect(jsonPath("$.catalog.rules.length()").value(0));
    }

    @Test
    void versionCasProtectsDifferentDevicesAndOwnerIsolation() throws Exception {
        var alice = user();
        var bob = user();
        String aliceAuth = jwt(alice.id);
        String bobAuth = jwt(bob.id);
        String body = "{\"expectedVersion\":0,\"catalog\":" + CATALOG + "}";
        mvc.perform(put(PATH).header("Authorization", aliceAuth)
            .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1))
            .andExpect(jsonPath("$.catalog.rules[0].value").value("Studio"));
        mvc.perform(put(PATH).header("Authorization", aliceAuth)
            .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict());
        mvc.perform(get(PATH).header("Authorization", bobAuth))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(0))
            .andExpect(jsonPath("$.catalog.rules.length()").value(0));
        mvc.perform(put(PATH).header("Authorization", bobAuth)
            .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1));
        mvc.perform(get(PATH).header("Authorization", aliceAuth))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.catalog.rules[0].value").value("Studio"));
        mvc.perform(put(PATH).header("Authorization", aliceAuth)
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"expectedVersion\":1,\"catalog\":{\"schema\":1,\"rules\":[]}}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(2));
        mvc.perform(get(PATH).header("Authorization", bobAuth))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.catalog.rules.length()").value(1));
    }

    @Test
    void rejectsUnknownFieldsDuplicateIdsFutureSchemasAndInvalidValues()
            throws Exception {
        var owner = user();
        String auth = jwt(owner.id);
        String[] invalid = {
            "{\"schema\":99,\"rules\":[]}",
            "{\"schema\":1,\"rules\":[],\"extra\":true}",
            "{\"schema\":1,\"rules\":[{\"id\":\"action-abc123\",\"trigger\":\"created\",\"action\":\"priority\",\"value\":\"4\",\"titleContains\":\"\",\"enabled\":true}]}",
            "{\"schema\":1,\"rules\":[{\"id\":\"action-abc123\",\"trigger\":\"created\",\"action\":\"list\",\"value\":\"not-a-uuid\",\"titleContains\":\"\",\"enabled\":true}]}",
            "{\"schema\":1,\"rules\":[{\"id\":\"action-abc123\",\"trigger\":\"created\",\"action\":\"tag\",\"value\":\"A\",\"titleContains\":\"\",\"enabled\":true},{\"id\":\"action-abc123\",\"trigger\":\"completed\",\"action\":\"tag\",\"value\":\"B\",\"titleContains\":\"\",\"enabled\":true}]}",
        };
        for (String catalog : invalid) {
            mvc.perform(put(PATH).header("Authorization", auth)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"expectedVersion\":0,\"catalog\":" + catalog + "}"))
                .andExpect(status().isBadRequest());
        }
        mvc.perform(get(PATH).header("Authorization", auth))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(0));
    }

    @Test
    void staleWriteNeverChangesServerOrLocalTaskHistory() throws Exception {
        var owner = user();
        String auth = jwt(owner.id);
        mvc.perform(put(PATH).header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"expectedVersion\":0,\"catalog\":" + CATALOG + "}"))
            .andExpect(status().isOk());
        mvc.perform(put(PATH).header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"expectedVersion\":0,\"catalog\":{\"schema\":1,\"rules\":[]}}"))
            .andExpect(status().isConflict());
        mvc.perform(get(PATH).header("Authorization", auth))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1))
            .andExpect(jsonPath("$.catalog.rules.length()").value(1));
        mvc.perform(get("/api/v1/sync/changes")
            .header("Authorization", auth).param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(0));
    }
}
