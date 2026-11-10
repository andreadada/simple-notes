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
class UserTemplateCatalogIntegrationTest {
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

    private String token(UUID owner) {
        var now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("simple-notes-api")
            .audience(List.of("simple-notes")).subject(owner.toString())
            .issuedAt(now).expiresAt(now.plusSeconds(600)).build();
        return "Bearer " + encoder.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    private AppUser user() {
        return users.save(new AppUser("template-" + UUID.randomUUID(),
            "model@example.com", "Models"));
    }
    private static final String PATH = "/api/v1/templates/catalog";
    private static final String LIB = """
        {"schema":1,"templates":[{"id":"custom-abc123","title":"Esame",
        "description":"Ripassare","priority":2,"tags":["Uni"],
        "subtasks":["Capitolo 1"]}]}
        """;

    @Test
    void jwtAndAccountIsolationWithCas() throws Exception {
        mvc.perform(get(PATH)).andExpect(status().isUnauthorized());
        var alice = user();
        var bob = user();
        var a = token(alice.id);
        var b = token(bob.id);
        mvc.perform(get(PATH).header("Authorization", a))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0))
            .andExpect(jsonPath("$.catalog.templates.length()").value(0));
        String first = "{\"expectedVersion\":0,\"catalog\":" + LIB + "}";
        mvc.perform(put(PATH).header("Authorization", a)
            .contentType(MediaType.APPLICATION_JSON).content(first))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));
        mvc.perform(put(PATH).header("Authorization", a)
            .contentType(MediaType.APPLICATION_JSON).content(first))
            .andExpect(status().isConflict());
        mvc.perform(get(PATH).header("Authorization", b))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));
        mvc.perform(get(PATH).header("Authorization", a))
            .andExpect(jsonPath("$.catalog.templates[0].title").value("Esame"));
        mvc.perform(get("/api/v1/sync/changes").header("Authorization", a)
            .param("cursor", "0")).andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(0));
    }

    @Test
    void validatesStrictSchemaWithoutWritingAnything() throws Exception {
        var auth = token(user().id);
        String[] invalid = {
            "{\"schema\":2,\"templates\":[]}",
            "{\"schema\":1,\"templates\":[],\"unknown\":true}",
            "{\"schema\":1,\"templates\":[{\"id\":\"custom-a\",\"title\":\"\",\"description\":\"\",\"priority\":0,\"tags\":[],\"subtasks\":[]}]}",
            "{\"schema\":1,\"templates\":[{\"id\":\"custom-a\",\"title\":\"A\",\"description\":\"\",\"priority\":4,\"tags\":[],\"subtasks\":[]}]}",
            "{\"schema\":1,\"templates\":[{\"id\":\"custom-a\",\"title\":\"A\",\"description\":\"\",\"priority\":0,\"tags\":[],\"subtasks\":[]},{\"id\":\"custom-a\",\"title\":\"B\",\"description\":\"\",\"priority\":0,\"tags\":[],\"subtasks\":[]}]}"
        };
        for (var catalog : invalid) {
            mvc.perform(put(PATH).header("Authorization", auth)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"expectedVersion\":0,\"catalog\":" + catalog + "}"))
                .andExpect(status().isBadRequest());
        }
        mvc.perform(get(PATH).header("Authorization", auth))
            .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(0));
    }
}
