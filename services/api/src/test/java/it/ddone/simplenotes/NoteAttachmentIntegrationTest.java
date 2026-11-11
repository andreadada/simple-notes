package it.ddone.simplenotes;

import it.ddone.simplenotes.attachment.AttachmentObjectStore;
import it.ddone.simplenotes.attachment.NoteAttachmentRepository;
import it.ddone.simplenotes.note.NoteEntity;
import it.ddone.simplenotes.note.NoteRepository;
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
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class NoteAttachmentIntegrationTest {
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
    @Autowired NoteRepository notes;
    @Autowired NoteAttachmentRepository attachments;
    @Autowired JwtEncoder encoder;
    @Autowired ObjectMapper json;
    @MockitoBean AttachmentObjectStore objects;

    private String auth(UUID owner) {
        var now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("simple-notes-api")
            .audience(List.of("simple-notes")).subject(owner.toString())
            .issuedAt(now).expiresAt(now.plusSeconds(600)).build();
        return "Bearer " + encoder.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }
    private AppUser user() {
        return users.save(new AppUser("attach-" + UUID.randomUUID(),
            "attachment@example.com", "Attachments"));
    }
    private NoteEntity note(AppUser user) {
        return notes.save(new NoteEntity(user.id, "Notes", "Body"));
    }
    private String route(UUID note) {
        return "/api/v1/notes/" + note + "/attachments";
    }
    private static final String REQUEST = """
        {"name":"lecture.pdf","contentType":"application/pdf","sizeBytes":1024}
        """;

    @Test
    void ownerScopedLifecycleNeverWritesSyncHistory() throws Exception {
        var alice = user();
        var bob = user();
        var note = note(alice);
        var url = route(note.id);
        when(objects.presignPut(anyString(), eq("application/pdf"), eq(1024L)))
            .thenReturn(new AttachmentObjectStore.Ticket(
                "https://s3.example/staging/upload",
                java.util.Map.of("Content-Type", "application/pdf")));
        when(objects.inspect(anyString())).thenReturn(
            new AttachmentObjectStore.Metadata(1024L, "application/pdf", "\"etag-1\""));
        when(objects.readPrefix(anyString(), eq("\"etag-1\""), eq(512)))
            .thenReturn("%PDF-1.7".getBytes(java.nio.charset.StandardCharsets.US_ASCII));
        when(objects.presignGet(anyString())).thenReturn(
            "https://s3.example/files/read");

        mvc.perform(get(url)).andExpect(status().isUnauthorized());
        mvc.perform(get(url).header("Authorization", auth(bob.id)))
            .andExpect(status().isNotFound());
        mvc.perform(post(url).header("Authorization", auth(bob.id))
            .contentType(MediaType.APPLICATION_JSON).content(REQUEST))
            .andExpect(status().isNotFound());
        var response = mvc.perform(post(url)
            .header("Authorization", auth(alice.id))
            .contentType(MediaType.APPLICATION_JSON).content(REQUEST))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.uploadUrl").value("https://s3.example/staging/upload"))
            .andExpect(jsonPath("$.headers.Content-Type").value("application/pdf"))
            .andReturn().getResponse().getContentAsString();
        UUID id = UUID.fromString(json.readTree(response).path("id").asText());
        mvc.perform(get(url).header("Authorization", auth(alice.id)))
            .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
        mvc.perform(post(url + "/" + id + "/complete")
            .header("Authorization", auth(bob.id)))
            .andExpect(status().isNotFound());
        mvc.perform(post(url + "/" + id + "/complete")
            .header("Authorization", auth(alice.id)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("lecture.pdf"))
            .andExpect(jsonPath("$.sizeBytes").value(1024));
        mvc.perform(post(url + "/" + id + "/complete")
            .header("Authorization", auth(alice.id)))
            .andExpect(status().isOk());
        verify(objects, times(1)).promote(
            anyString(), anyString(), eq("application/pdf"), eq("\"etag-1\""));
        mvc.perform(get(url + "/" + id + "/download")
            .header("Authorization", auth(alice.id)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.downloadUrl").value("https://s3.example/files/read"));
        mvc.perform(get(url + "/" + id + "/download")
            .header("Authorization", auth(bob.id)))
            .andExpect(status().isNotFound());
        mvc.perform(get(url).header("Authorization", auth(alice.id)))
            .andExpect(jsonPath("$.length()").value(1));
        mvc.perform(delete(url + "/" + id)
            .header("Authorization", auth(alice.id)))
            .andExpect(status().isNoContent());
        mvc.perform(get(url).header("Authorization", auth(alice.id)))
            .andExpect(jsonPath("$.length()").value(0));
        mvc.perform(get("/api/v1/sync/changes")
            .header("Authorization", auth(alice.id)).param("cursor", "0"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.changes.length()").value(0));
    }

    @Test
    void rejectsDangerousFilesAndNeverConfirmsWrongObject() throws Exception {
        var alice = user();
        var note = note(alice);
        var url = route(note.id);
        var auth = auth(alice.id);
        for (String payload : List.of(
                "{\"name\":\"../secret.txt\",\"contentType\":\"text/plain\",\"sizeBytes\":50}",
                "{\"name\":\"index.html\",\"contentType\":\"text/html\",\"sizeBytes\":50}",
                "{\"name\":\"giant.pdf\",\"contentType\":\"application/pdf\",\"sizeBytes\":10485761}",
                "{\"name\":\"test.png\",\"contentType\":\"image/png\",\"sizeBytes\":0}")) {
            mvc.perform(post(url).header("Authorization", auth)
                .contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isBadRequest());
        }
        when(objects.presignPut(anyString(), eq("application/pdf"), eq(1024L)))
            .thenReturn(new AttachmentObjectStore.Ticket(
                "https://s3.example/pending", java.util.Map.of()));
        when(objects.inspect(anyString())).thenReturn(
            new AttachmentObjectStore.Metadata(1025L, "application/pdf", "\"etag-2\""));
        var response = mvc.perform(post(url).header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(REQUEST))
            .andExpect(status().isCreated()).andReturn().getResponse()
            .getContentAsString();
        UUID id = UUID.fromString(json.readTree(response).path("id").asText());
        mvc.perform(post(url + "/" + id + "/complete")
            .header("Authorization", auth)).andExpect(status().isConflict());
        verify(objects, never()).promote(
            anyString(), anyString(), anyString(), anyString());
        mvc.perform(get(url).header("Authorization", auth))
            .andExpect(jsonPath("$.length()").value(0));
        mvc.perform(get(url + "/" + id + "/download")
            .header("Authorization", auth)).andExpect(status().isNotFound());
        note.deletedAt = Instant.now();
        notes.saveAndFlush(note);
        mvc.perform(post(url).header("Authorization", auth)
            .contentType(MediaType.APPLICATION_JSON).content(REQUEST))
            .andExpect(status().isNotFound());
    }
    @Test
    void spoofedPdfIsNeverPromotedOrListed() throws Exception {
        var alice = user();
        var note = note(alice);
        var url = route(note.id);
        var authorization = auth(alice.id);
        when(objects.presignPut(anyString(), eq("application/pdf"), eq(1024L)))
            .thenReturn(new AttachmentObjectStore.Ticket(
                "https://s3.example/staging/upload", java.util.Map.of()));
        when(objects.inspect(anyString())).thenReturn(
            new AttachmentObjectStore.Metadata(1024L, "application/pdf", "\"etag-3\""));
        when(objects.readPrefix(anyString(), eq("\"etag-3\""), eq(512)))
            .thenReturn("<html><script>x</script></html>"
                .getBytes(java.nio.charset.StandardCharsets.US_ASCII));
        var response = mvc.perform(post(url).header("Authorization", authorization)
            .contentType(MediaType.APPLICATION_JSON).content(REQUEST))
            .andExpect(status().isCreated()).andReturn().getResponse()
            .getContentAsString();
        var id = UUID.fromString(json.readTree(response).path("id").asText());
        mvc.perform(post(url + "/" + id + "/complete")
            .header("Authorization", authorization))
            .andExpect(status().isConflict());
        mvc.perform(get(url).header("Authorization", authorization))
            .andExpect(jsonPath("$.length()").value(0));
        verify(objects, never()).promote(anyString(), anyString(),
            anyString(), anyString());
    }

    @Test
    void stalePendingMetadataIsPrunedWithoutDeletingS3Objects() {
        var owner = user();
        var note = note(owner);
        var stale = new it.ddone.simplenotes.attachment.NoteAttachmentEntity(
            owner.id, note.id, "old.pdf", "application/pdf", 10,
            Instant.now().minusSeconds(2 * 86400));
        var fresh = new it.ddone.simplenotes.attachment.NoteAttachmentEntity(
            owner.id, note.id, "new.pdf", "application/pdf", 10,
            Instant.now());
        attachments.saveAndFlush(stale);
        attachments.saveAndFlush(fresh);
        var maintenance = new it.ddone.simplenotes.attachment.PendingAttachmentMaintenance(
            attachments);
        org.springframework.test.util.ReflectionTestUtils.setField(
            maintenance, "enabled", true);
        try {
            org.assertj.core.api.Assertions.assertThat(maintenance.pruneExpired())
                .isEqualTo(1);
            org.assertj.core.api.Assertions.assertThat(
                attachments.findById(stale.id)).isEmpty();
            org.assertj.core.api.Assertions.assertThat(
                attachments.findById(fresh.id)).isPresent();
            verify(objects, never()).delete(anyString());
        } finally {
            org.springframework.test.util.ReflectionTestUtils.setField(
                maintenance, "enabled", false);
        }
    }

}
