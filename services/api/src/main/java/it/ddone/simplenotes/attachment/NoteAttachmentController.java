package it.ddone.simplenotes.attachment;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/notes/{noteId}/attachments")
public class NoteAttachmentController {
    public record Begin(
        @NotBlank @Size(max = 180) String name,
        @NotBlank String contentType,
        @Min(1) @Max(10485760) long sizeBytes) {}
    public record View(UUID id, String name, String contentType,
            long sizeBytes, Instant createdAt) {
        static View from(NoteAttachmentEntity value) {
            return new View(value.id, value.fileName,
                value.contentType, value.sizeBytes, value.createdAt);
        }
    }
    public record Upload(UUID id, String uploadUrl,
            Map<String, String> headers, Instant expiresAt) {}
    public record Download(String downloadUrl, Instant expiresAt) {}

    private final NoteAttachmentService service;
    public NoteAttachmentController(NoteAttachmentService service) {
        this.service = service;
    }
    private UUID owner(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }

    @GetMapping
    public List<View> list(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID noteId) {
        return service.list(owner(jwt), noteId).stream().map(View::from).toList();
    }
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Upload begin(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID noteId, @Valid @RequestBody Begin input) {
        return service.begin(owner(jwt), noteId, input);
    }
    @PostMapping("/{id}/complete")
    public View complete(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID noteId, @PathVariable UUID id) {
        return View.from(service.complete(owner(jwt), noteId, id));
    }
    @GetMapping("/{id}/download")
    public Download download(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID noteId, @PathVariable UUID id) {
        return service.download(owner(jwt), noteId, id);
    }
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID noteId, @PathVariable UUID id) {
        service.delete(owner(jwt), noteId, id);
    }
}
