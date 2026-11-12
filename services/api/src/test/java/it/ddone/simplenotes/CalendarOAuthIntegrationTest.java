package it.ddone.simplenotes;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import it.ddone.simplenotes.calendar.CalendarHttpGateway;
import it.ddone.simplenotes.user.AppUser;
import it.ddone.simplenotes.user.AppUserRepository;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class CalendarOAuthIntegrationTest {
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
        r.add("app.calendar.public-origin", () -> "https://api.example.test");
        r.add("app.calendar.token-key-base64",
            () -> "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=");
        r.add("app.calendar.google-client-id", () -> "calendar-google-id");
        r.add("app.calendar.google-client-secret", () -> "calendar-google-secret");
        r.add("app.calendar.microsoft-client-id", () -> "calendar-ms-id");
        r.add("app.calendar.microsoft-client-secret", () -> "calendar-ms-secret");
    }

    @Autowired MockMvc mvc;
    @Autowired AppUserRepository users;
    @Autowired JwtEncoder encoder;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;
    @MockitoBean CalendarHttpGateway provider;

    private AppUser user() {
        return users.save(new AppUser("calendar-" + UUID.randomUUID(),
            "test@example.invalid", "Calendar Test"));
    }

    private String auth(AppUser person) {
        Instant now = Instant.now();
        return "Bearer " + encoder.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(),
            JwtClaimsSet.builder().issuer("simple-notes-api")
                .audience(List.of("simple-notes")).subject(person.id.toString())
                .issuedAt(now).expiresAt(now.plusSeconds(600)).build()))
            .getTokenValue();
    }

    private String begin(AppUser person, String type) throws Exception {
        String response = mvc.perform(post("/api/v1/calendars/" + type + "/authorize")
            .header("Authorization", auth(person)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.authorizationUrl").isString())
            .andReturn().getResponse().getContentAsString();
        String uri = json.readTree(response).path("authorizationUrl").asText();
        assertTrue(uri.startsWith(type.equals("google")
            ? "https://accounts.google.com/" : "https://login.microsoftonline.com/"));
        String state = Arrays.stream(URI.create(uri).getRawQuery().split("&"))
            .filter(x -> x.startsWith("state=")).findFirst().orElseThrow()
            .substring("state=".length());
        assertEquals(43, state.length());
        assertTrue(uri.contains("code_challenge_method=S256"));
        assertTrue(uri.contains("api.example.test"));
        return URLDecoder.decode(state, StandardCharsets.UTF_8);
    }

    @Test
    void oneTimeStateAndEncryptedTokensAndAccountIsolation() throws Exception {
        AppUser alice = user(), bob = user();
        mvc.perform(get("/api/v1/calendars"))
            .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/calendars").header("Authorization", auth(alice)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].provider").value("google"))
            .andExpect(jsonPath("$[0].available").value(true))
            .andExpect(jsonPath("$[0].connected").value(false));

        String state = begin(alice, "google");
        when(provider.token(any(), anyMap()))
            .thenReturn(json.readTree("""
                {"access_token":"secret-access-123","refresh_token":"secret-refresh-456","expires_in":3600}
                """));
        mvc.perform(get("/api/v1/calendars/oauth/google/callback")
            .param("state", state).param("code", "provider-code"))
            .andExpect(status().isOk());
        mvc.perform(get("/api/v1/calendars/oauth/google/callback")
            .param("state", state).param("code", "provider-code"))
            .andExpect(status().isBadRequest());
        String stored = jdbc.queryForObject(
            "SELECT access_token_encrypted FROM calendar_oauth_connection"
                + " WHERE owner_id=? AND provider='google'", String.class, alice.id);
        assertNotNull(stored);
        assertFalse(stored.contains("secret-access"));
        assertEquals(0, jdbc.queryForObject(
            "SELECT COUNT(*) FROM calendar_oauth_connection WHERE owner_id=?",
            Integer.class, bob.id));
        mvc.perform(get("/api/v1/calendars").header("Authorization", auth(alice)))
            .andExpect(jsonPath("$[0].connected").value(true));
        mvc.perform(get("/api/v1/calendars").header("Authorization", auth(bob)))
            .andExpect(jsonPath("$[0].connected").value(false));

        mvc.perform(get("/api/v1/calendars/google/events")
            .header("Authorization", auth(bob))
            .param("start","2026-11-12T00:00:00Z")
            .param("end","2026-11-13T00:00:00Z"))
            .andExpect(status().isNotFound());
        when(provider.read(any(), eq("secret-access-123"), eq(false)))
            .thenReturn(json.readTree("""
                {"items":[{"id":"event-1","summary":"Appointment",
                "start":{"dateTime":"2026-11-12T10:00:00+01:00"},
                "end":{"dateTime":"2026-11-12T11:00:00+01:00"}}]}
                """));
        mvc.perform(get("/api/v1/calendars/google/events")
            .header("Authorization", auth(alice))
            .param("start","2026-11-12T00:00:00Z")
            .param("end","2026-11-13T00:00:00Z"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.events[0].title").value("Appointment"))
            .andExpect(jsonPath("$.events[0].startUtc").value("2026-11-12T09:00:00Z"));
        mvc.perform(delete("/api/v1/calendars/google")
            .header("Authorization", auth(bob)))
            .andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/calendars").header("Authorization", auth(alice)))
            .andExpect(jsonPath("$[0].connected").value(true));
        mvc.perform(delete("/api/v1/calendars/google")
            .header("Authorization", auth(alice)))
            .andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/calendars").header("Authorization", auth(alice)))
            .andExpect(jsonPath("$[0].connected").value(false));
    }

    @Test
    void expiryCancellationProviderAndRangeValidation() throws Exception {
        AppUser alice = user();
        String expired = begin(alice, "microsoft");
        jdbc.update("UPDATE calendar_oauth_attempt SET expires_at=now()-interval '1 minute'"
            + " WHERE owner_id=?", alice.id);
        mvc.perform(get("/api/v1/calendars/oauth/microsoft/callback")
            .param("state",expired).param("code","provider-code"))
            .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/calendars/unknown/authorize")
            .header("Authorization", auth(alice)))
            .andExpect(status().isNotFound());
        String cancelled = begin(alice,"google");
        mvc.perform(get("/api/v1/calendars/oauth/google/callback")
            .param("state",cancelled).param("error","access_denied"))
            .andExpect(status().isBadRequest());
        assertEquals(0, jdbc.queryForObject(
            "SELECT COUNT(*) FROM calendar_oauth_attempt WHERE owner_id=?",
            Integer.class, alice.id));
        mvc.perform(get("/api/v1/calendars/google/events")
            .header("Authorization", auth(alice))
            .param("start","2026-11-12T00:00:00Z")
            .param("end","2026-12-20T00:00:00Z"))
            .andExpect(status().isBadRequest());
        verifyNoInteractions(provider);
    }
}
