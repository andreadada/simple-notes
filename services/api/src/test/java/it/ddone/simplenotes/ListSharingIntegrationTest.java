package it.ddone.simplenotes;

import com.fasterxml.jackson.databind.ObjectMapper;
import it.ddone.simplenotes.task.TaskEntity;
import it.ddone.simplenotes.task.TaskListEntity;
import it.ddone.simplenotes.task.TaskListRepository;
import it.ddone.simplenotes.task.TaskRepository;
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
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Real PostgreSQL / JWT tests; no outbound email, S3 or production data. */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class ListSharingIntegrationTest {
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
    @Autowired TaskListRepository lists;
    @Autowired TaskRepository tasks;
    @Autowired JdbcTemplate jdbc;
    @Autowired JwtEncoder encoder;
    @Autowired ObjectMapper json;

    private AppUser user() {
        return users.save(new AppUser("share-" + UUID.randomUUID(),
            "testing@example.invalid", "Collaborator"));
    }
    private String auth(UUID user) {
        var now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("simple-notes-api")
            .audience(List.of("simple-notes")).subject(user.toString())
            .issuedAt(now).expiresAt(now.plusSeconds(600)).build();
        return "Bearer " + encoder.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }
    private TaskListEntity list(AppUser owner, String title) {
        return lists.saveAndFlush(new TaskListEntity(owner.id, title));
    }
    private String invite(UUID owner, UUID list) throws Exception {
        String response = mvc.perform(post("/api/v1/sharing/lists/" + list + "/invitations")
            .header("Authorization", auth(owner)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.token").isString())
            .andReturn().getResponse().getContentAsString();
        String token = json.readTree(response).path("token").textValue();
        assertThat(token).hasSize(43);
        return token;
    }
    private void accept(UUID member, String token) throws Exception {
        mvc.perform(post("/api/v1/sharing/invitations/accept")
            .header("Authorization", auth(member))
            .contentType(MediaType.APPLICATION_JSON)
            .content(json.writeValueAsString(java.util.Map.of("token", token))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.role").value("VIEWER"));
    }

    @Test
    void requiresAuthAndKeepsOwnerLedgerAndPrivateListsIsolated() throws Exception {
        var alice = user();
        var bob = user();
        var eve = user();
        var shared = list(alice,"Project");
        var privateList = list(alice,"Secrets");
        var publicTask = new TaskEntity(alice.id,"Visible", "Shared description",null);
        publicTask.listId = shared.id;
        tasks.saveAndFlush(publicTask);
        var privateTask = new TaskEntity(alice.id,"Private task","Never shared",null);
        privateTask.listId = privateList.id;
        tasks.saveAndFlush(privateTask);
        var url = "/api/v1/sharing/lists/" + shared.id;

        mvc.perform(post(url + "/invitations"))
            .andExpect(status().isUnauthorized());
        mvc.perform(get(url + "/snapshot"))
            .andExpect(status().isUnauthorized());
        mvc.perform(post(url + "/invitations")
            .header("Authorization", auth(bob.id)))
            .andExpect(status().isNotFound());
        mvc.perform(get(url + "/snapshot")
            .header("Authorization", auth(bob.id)))
            .andExpect(status().isNotFound());
        String token = invite(alice.id, shared.id);
        mvc.perform(get(url + "/invitations")
            .header("Authorization", auth(bob.id)))
            .andExpect(status().isNotFound());
        mvc.perform(get(url + "/invitations")
            .header("Authorization", auth(alice.id)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].token").doesNotExist());

        mvc.perform(get(url + "/snapshot")
            .header("Authorization", auth(eve.id)))
            .andExpect(status().isNotFound());
        accept(bob.id,token);
        mvc.perform(get("/api/v1/sharing/lists")
            .header("Authorization", auth(bob.id)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].id").value(shared.id.toString()))
            .andExpect(jsonPath("$[0].role").value("VIEWER"));
        mvc.perform(get(url + "/snapshot")
            .header("Authorization", auth(bob.id)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.title").value("Project"))
            .andExpect(jsonPath("$.readOnly").value(true))
            .andExpect(jsonPath("$.tasks.length()").value(1))
            .andExpect(jsonPath("$.tasks[0].title").value("Visible"))
            .andExpect(jsonPath("$.tasks[0].description").value("Shared description"));
        mvc.perform(get("/api/v1/sharing/lists/" + privateList.id + "/snapshot")
            .header("Authorization", auth(bob.id)))
            .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/tasks")
            .header("Authorization", auth(bob.id)))
            .andExpect(jsonPath("$.length()").value(0));
        mvc.perform(get("/api/v1/sync/changes")
            .header("Authorization", auth(bob.id)).param("cursor","0"))
            .andExpect(jsonPath("$.changes.length()").value(0));
        mvc.perform(delete(url + "/members/" + bob.id)
            .header("Authorization", auth(eve.id)))
            .andExpect(status().isNotFound());
        mvc.perform(delete(url + "/members/" + bob.id)
            .header("Authorization", auth(alice.id)))
            .andExpect(status().isNoContent());
        mvc.perform(get(url + "/snapshot")
            .header("Authorization", auth(bob.id)))
            .andExpect(status().isNotFound());
    }

    @Test
    void tokensAreSingleUseHashedRevocableAndCannotBeSelfRedeemed()
            throws Exception {
        var owner=user();
        var bob=user();
        var eve=user();
        var list=list(owner,"Invites");
        var route="/api/v1/sharing/lists/"+list.id;
        String token=invite(owner.id,list.id);
        Integer matches=jdbc.queryForObject(
            "SELECT COUNT(*) FROM list_share_invitation WHERE token_hash=?",
            Integer.class,token);
        assertThat(matches).isEqualTo(0);
        mvc.perform(post("/api/v1/sharing/invitations/accept")
            .header("Authorization",auth(owner.id))
            .contentType(MediaType.APPLICATION_JSON)
            .content(json.writeValueAsString(java.util.Map.of("token",token))))
            .andExpect(status().isConflict());
        mvc.perform(post("/api/v1/sharing/invitations/accept")
            .header("Authorization",auth(bob.id))
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"token\":\"invalid\"}"))
            .andExpect(status().isBadRequest());
        accept(bob.id,token);
        mvc.perform(post("/api/v1/sharing/invitations/accept")
            .header("Authorization",auth(eve.id))
            .contentType(MediaType.APPLICATION_JSON)
            .content(json.writeValueAsString(java.util.Map.of("token",token))))
            .andExpect(status().isConflict());
        mvc.perform(delete(route + "/membership")
            .header("Authorization",auth(bob.id)))
            .andExpect(status().isNoContent());
        mvc.perform(get(route + "/snapshot")
            .header("Authorization",auth(bob.id)))
            .andExpect(status().isNotFound());

        String revoked=invite(owner.id,list.id);
        UUID invitation = jdbc.queryForObject(
            "SELECT id FROM list_share_invitation WHERE token_hash <> ? " +
            "AND list_id=? AND revoked_at IS NULL AND redeemed_at IS NULL " +
            "ORDER BY created_at DESC LIMIT 1", UUID.class,
            "never-a-digest",list.id);
        mvc.perform(delete(route + "/invitations/" + invitation)
            .header("Authorization",auth(owner.id)))
            .andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/sharing/invitations/accept")
            .header("Authorization",auth(eve.id))
            .contentType(MediaType.APPLICATION_JSON)
            .content(json.writeValueAsString(java.util.Map.of("token",revoked))))
            .andExpect(status().isConflict());

        String expired=invite(owner.id,list.id);
        jdbc.update("UPDATE list_share_invitation SET expires_at=now()-INTERVAL '1 second' " +
            "WHERE list_id=? AND redeemed_at IS NULL AND revoked_at IS NULL",list.id);
        mvc.perform(post("/api/v1/sharing/invitations/accept")
            .header("Authorization",auth(eve.id))
            .contentType(MediaType.APPLICATION_JSON)
            .content(json.writeValueAsString(java.util.Map.of("token",expired))))
            .andExpect(status().isConflict());
    }

    @Test
    void invitationsHaveBoundedCapacityAndDeletedListIsNotShared() throws Exception {
        var owner=user();
        var member=user();
        var list=list(owner,"Limited");
        String path="/api/v1/sharing/lists/"+list.id+"/invitations";
        for (int i=0;i<5;i++) invite(owner.id,list.id);
        mvc.perform(post(path).header("Authorization",auth(owner.id)))
            .andExpect(status().isConflict());
        list.deletedAt=Instant.now();
        lists.saveAndFlush(list);
        mvc.perform(post(path).header("Authorization",auth(owner.id)))
            .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/sharing/lists/"+list.id+"/snapshot")
            .header("Authorization",auth(member.id)))
            .andExpect(status().isNotFound());
    }

    @Test
    void snapshotPaginationDoesNotReadOtherLists() throws Exception {
        var owner=user();
        var member=user();
        var list=list(owner,"Paged");
        for (int i=0;i<51;i++) {
            var task = new TaskEntity(owner.id,"task-"+i,"body-"+i,null);
            task.listId=list.id;
            tasks.save(task);
        }
        tasks.flush();
        accept(member.id,invite(owner.id,list.id));
        String path="/api/v1/sharing/lists/"+list.id+"/snapshot";
        mvc.perform(get(path).header("Authorization",auth(member.id)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.tasks.length()").value(50))
            .andExpect(jsonPath("$.nextOffset").value(50));
        mvc.perform(get(path).header("Authorization",auth(member.id))
            .param("offset","50"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.tasks.length()").value(1))
            .andExpect(jsonPath("$.nextOffset").isEmpty());
        mvc.perform(get(path).header("Authorization",auth(member.id))
            .param("offset","-1"))
            .andExpect(status().isBadRequest());
    }
}
