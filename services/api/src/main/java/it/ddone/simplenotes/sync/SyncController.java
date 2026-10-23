package it.ddone.simplenotes.sync;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/sync")
public class SyncController {
    public record ApplyRequest(@NotNull UUID operationId, @NotNull UUID entityId,
        @NotBlank String entityType, @NotBlank String action, Long expectedVersion,
        JsonNode payload) {}
    public record ApplyResponse(UUID operationId, long version, long changeId) {}
    public record Change(long changeId, String entityType, UUID entityId,
        JsonNode payload, boolean deleted, long version) {}
    public record Changes(List<Change> changes, long nextCursor, boolean hasMore) {}
    public record LatestChange(String entityType, UUID entityId, JsonNode payload,
        boolean deleted, long version, long changeId) {}

    private final SyncService service;
    public SyncController(SyncService service) { this.service = service; }
    private UUID owner(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }

    @PostMapping("/apply")
    public ApplyResponse apply(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ApplyRequest body) {
        return service.apply(owner(jwt), body);
    }
    @GetMapping("/latest")
    public LatestChange latest(@AuthenticationPrincipal Jwt jwt,
            @RequestParam String entityType, @RequestParam UUID entityId) {
        return service.latest(owner(jwt), entityType, entityId);
    }

    @GetMapping("/changes")
    public Changes changes(@AuthenticationPrincipal Jwt jwt,
                           @RequestParam(defaultValue = "0") @Min(0) long cursor,
                           @RequestParam(defaultValue = "100") @Min(1) @Max(200) int limit) {
        return service.changes(owner(jwt), cursor, limit);
    }
}
