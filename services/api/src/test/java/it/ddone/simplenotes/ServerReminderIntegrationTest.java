package it.ddone.simplenotes;

import it.ddone.simplenotes.reminder.ServerReminderService;
import it.ddone.simplenotes.user.AppUser;
import it.ddone.simplenotes.user.AppUserRepository;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
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
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class ServerReminderIntegrationTest {
    @Container
    static final PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:17-alpine");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("app.google.client-ids", () -> "test-google-client");
        registry.add("app.jwt.secret-base64",
            () -> "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVoxMjM0NTY=");
    }

    @Autowired MockMvc mvc;
    @Autowired AppUserRepository users;
    @Autowired JwtEncoder encoder;
    @Autowired JdbcTemplate jdbc;
    @Autowired ServerReminderService reminders;

    private AppUser user() {
        return users.save(new AppUser("reminder-" + UUID.randomUUID(),
            "reminder@example.invalid", "Reminder Test"));
    }

    private String bearer(UUID owner) {
        Instant now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("simple-notes-api")
            .audience(List.of("simple-notes")).subject(owner.toString())
            .issuedAt(now).expiresAt(now.plusSeconds(600)).build();
        return "Bearer " + encoder.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    private UUID task(UUID owner, String title, Instant due, String kind) {
        UUID id = UUID.randomUUID();
        LocalDateTime utc = LocalDateTime.ofInstant(due, ZoneOffset.UTC);
        if ("datetime".equals(kind)) {
            jdbc.update("""
                INSERT INTO task (id,owner_id,title,due_kind,due_at,
                    due_date,due_time,due_timezone,due_offset_seconds)
                VALUES (?,?,?,'datetime',?, ?,?,'UTC',0)
                """,id,owner,title,java.sql.Timestamp.from(due),
                utc.toLocalDate(),utc.toLocalTime());
        } else {
            jdbc.update("""
                INSERT INTO task (id,owner_id,title,due_kind,due_at)
                VALUES (?,?,?,'legacy',?)
                """,id,owner,title,java.sql.Timestamp.from(due));
        }
        return id;
    }

    private static String json(boolean enabled,int lead,long expected) {
        return "{\"enabled\":" + enabled + ",\"leadMinutes\":" + lead
            + ",\"expectedVersion\":" + expected + "}";
    }

    @Test
    void optInAndCasAndDedupAndOwnerScopedAcknowledgment() throws Exception {
        var alice=user();
        var bob=user();
        String a=bearer(alice.id), b=bearer(bob.id);
        String path="/api/v1/reminders/server";

        mvc.perform(get(path+"/preferences"))
            .andExpect(status().isUnauthorized());
        mvc.perform(get(path+"/preferences").header("Authorization",a))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.enabled").value(false))
            .andExpect(jsonPath("$.version").value(0));

        UUID alphaTask=task(alice.id,"Important",Instant.now().plusSeconds(840),
            "datetime");
        task(alice.id,"Legacy",Instant.now().plusSeconds(840),"legacy");
        task(bob.id,"Bob",Instant.now().plusSeconds(840),"datetime");

        assertEquals(0,reminders.scan());
        mvc.perform(put(path+"/preferences").header("Authorization",a)
            .contentType(MediaType.APPLICATION_JSON).content(json(true,15,0)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.enabled").value(true))
            .andExpect(jsonPath("$.version").value(1));
        mvc.perform(put(path+"/preferences").header("Authorization",a)
            .contentType(MediaType.APPLICATION_JSON).content(json(false,15,0)))
            .andExpect(status().isConflict());

        assertEquals(1,reminders.scan());
        assertEquals(0,reminders.scan());
        assertEquals(1,reminders.unread(alice.id).size());
        assertEquals(0,reminders.unread(bob.id).size());
        UUID occurrence=reminders.unread(alice.id).get(0).id();
        assertEquals(alphaTask,reminders.unread(alice.id).get(0).taskId());
        mvc.perform(get(path+"/occurrences").header("Authorization",a))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(1))
            .andExpect(jsonPath("$[0].title").value("Important"));
        mvc.perform(post(path+"/occurrences/"+occurrence+"/ack")
            .header("Authorization",b)).andExpect(status().isNotFound());
        mvc.perform(post(path+"/occurrences/"+occurrence+"/ack")
            .header("Authorization",a)).andExpect(status().isNoContent());
        mvc.perform(post(path+"/occurrences/"+occurrence+"/ack")
            .header("Authorization",a)).andExpect(status().isNoContent());
        assertTrue(reminders.unread(alice.id).isEmpty());

        mvc.perform(put(path+"/preferences").header("Authorization",a)
            .contentType(MediaType.APPLICATION_JSON).content(json(false,15,1)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.enabled").value(false));
        assertTrue(reminders.unread(alice.id).isEmpty());
        assertEquals(0,reminders.scan());
    }

    @Test
    void changedOrCompletedTaskCannotReappearAndInvalidSettingsRejected()
            throws Exception {
        var alice=user();
        String auth=bearer(alice.id),path="/api/v1/reminders/server";
        mvc.perform(put(path+"/preferences").header("Authorization",auth)
            .contentType(MediaType.APPLICATION_JSON).content(json(true,1440,0)))
            .andExpect(status().isOk());
        UUID task=task(alice.id,"Tomorrow",Instant.now().plusSeconds(86400-200),
            "datetime");
        assertEquals(1,reminders.scan());
        assertEquals(1,reminders.unread(alice.id).size());
        jdbc.update("UPDATE task SET completed_at=now() WHERE id=?",task);
        assertTrue(reminders.unread(alice.id).isEmpty());

        mvc.perform(put(path+"/preferences").header("Authorization",auth)
            .contentType(MediaType.APPLICATION_JSON).content(json(true,7,1)))
            .andExpect(status().isBadRequest());
        mvc.perform(put(path+"/preferences").header("Authorization",auth)
            .contentType(MediaType.APPLICATION_JSON).content(json(true,15,1)))
            .andExpect(status().isOk());
        assertEquals(0,reminders.scan());
    }
    @Test
    void disablingAndChangingLeadNeverReplaysStaleUnreadAcrossDevices()
            throws Exception {
        var alice = user();
        String auth = bearer(alice.id), route = "/api/v1/reminders/server";
        UUID future = task(alice.id, "One reminder",
            Instant.now().plusSeconds(840), "datetime");

        mvc.perform(put(route + "/preferences").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(json(true, 15, 0)))
            .andExpect(status().isOk());
        assertEquals(1, reminders.scan());
        assertEquals(1, reminders.unread(alice.id).size());

        // Another device edits lead: current due alert must disappear
        // immediately, rather than lingering until the next scanner tick.
        mvc.perform(put(route + "/preferences").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(json(true, 5, 1)))
            .andExpect(status().isOk());
        assertTrue(reminders.unread(alice.id).isEmpty());
        assertEquals(1, jdbc.queryForObject(
            "SELECT count(*) FROM server_reminder_occurrence "
                + "WHERE owner_id=? AND acknowledged_at IS NOT NULL",
            Integer.class, alice.id));

        // Going back to the original lead must not resurrect that event.
        mvc.perform(put(route + "/preferences").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(json(true, 15, 2)))
            .andExpect(status().isOk());
        assertEquals(0, reminders.scan());
        assertTrue(reminders.unread(alice.id).isEmpty());

        // An opt-out also permanently clears the unseen occurrence.
        jdbc.update("UPDATE task SET due_at=due_at-INTERVAL '1 minute', "
            + "due_time=due_time-INTERVAL '1 minute' WHERE id=?", future);
        assertEquals(1, reminders.scan());
        assertEquals(1, reminders.unread(alice.id).size());
        mvc.perform(put(route + "/preferences").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(json(false, 15, 3)))
            .andExpect(status().isOk());
        mvc.perform(put(route + "/preferences").header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(json(true, 15, 4)))
            .andExpect(status().isOk());
        assertEquals(0, reminders.scan());
        assertTrue(reminders.unread(alice.id).isEmpty());
    }

}
