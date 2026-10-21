package it.ddone.simplenotes;

import it.ddone.simplenotes.user.AppUser;
import it.ddone.simplenotes.user.AppUserRepository;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
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
class ApiIntegrationTest {
    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:17-alpine");

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("app.google.client-ids", () -> "test-google-client");
        // Test-only signing key, never used in production.
        registry.add("app.jwt.secret-base64", () -> "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVoxMjM0NTY=");
    }

    @Autowired MockMvc mvc;
    @Autowired AppUserRepository users;
    @Autowired JwtEncoder jwtEncoder;

    private String tokenFor(AppUser user) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer("simple-notes-api").audience(List.of("simple-notes"))
            .subject(user.id.toString()).issuedAt(now).expiresAt(now.plusSeconds(600)).build();
        return jwtEncoder.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    @Test
    void anonymousAccessIsDenied() throws Exception {
        mvc.perform(get("/api/v1/tasks")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/tasks").contentType(MediaType.APPLICATION_JSON)
            .content("{\"title\":\"unauthorized\"}")).andExpect(status().isUnauthorized());
    }

    @Test
    void authorizedUserCanCreateAndReadTheirTasksOnly() throws Exception {
        AppUser alice = users.save(new AppUser("test-alice-" + java.util.UUID.randomUUID(), "a@example.com", "Alice"));
        AppUser bob = users.save(new AppUser("test-bob-" + java.util.UUID.randomUUID(), "b@example.com", "Bob"));
        mvc.perform(post("/api/v1/tasks")
            .header("Authorization", "Bearer " + tokenFor(alice))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"title\":\"Buy milk\"}"))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.title").value("Buy milk"));
        mvc.perform(get("/api/v1/tasks")
            .header("Authorization", "Bearer " + tokenFor(alice)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].title").value("Buy milk"));
        mvc.perform(get("/api/v1/tasks")
            .header("Authorization", "Bearer " + tokenFor(bob)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(0));
    }
}
