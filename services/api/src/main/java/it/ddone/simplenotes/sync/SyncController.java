package it.ddone.simplenotes.sync;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/sync")
public class SyncController {
    public record ApplyRequest(@NotNull UUID operationId, @NotNull UUID entityId,
        @NotBlank String entityType, @NotBlank String action, Long expectedVersion,
        JsonNode payload, @Min(0) Long expectedAccountCursor) {}
    public record ApplyResponse(UUID operationId, long version, long changeId) {}
    public record Change(long changeId, String entityType, UUID entityId,
        JsonNode payload, boolean deleted, long version) {}
    public record Changes(List<Change> changes, long nextCursor, boolean hasMore) {}
    public record LatestChange(String entityType, UUID entityId, JsonNode payload,
        boolean deleted, long version, long changeId) {}
    /// Metadata-only, scoped to the authenticated account. Never return note
    /// contents, Google identifiers, raw operation IDs or any backup content.
    public record InventoryItem(String entityType, UUID entityId,
        long version, boolean deleted, long changeId) {}
    public record Inventory(long cursor, List<InventoryItem> items,
        boolean complete) {}

    /// P2.4B2I: a read-only, owner-scoped snapshot comparison. The check
    /// cannot grant a future write lease or authorize a profile restore.
    public record ExpectedRevision(@NotBlank String entityType,
        @NotNull UUID entityId, Long changeId, Long version, Boolean deleted) {}
    public record ReconciliationCheckRequest(
        @NotNull @Min(0) Long expectedCursor,
        @NotNull @Size(min = 1, max = 100)
        List<@Valid ExpectedRevision> items) {}
    public record ObservedRevision(String entityType, UUID entityId,
        Long changeId, Long version, Boolean deleted, boolean matches) {}
    public record ReconciliationCheckResponse(long cursor,
        boolean cursorMatches, boolean consistent,
        List<ObservedRevision> items) {}

    private final SyncService service;
    public SyncController(SyncService service) { this.service = service; }
    private UUID owner(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }

    @PostMapping("/apply")
    public ApplyResponse apply(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ApplyRequest body) {
        return service.apply(owner(jwt), body);
    }

    // Explicit machine-readable conflict for one immutable operation intent.
    // No ID, note body, owner, fingerprint or mutation payload is returned.
    @ExceptionHandler(SyncOperationIntentConflict.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public Map<String, String> operationIdReuse() {
        return Map.of("code", "SYNC_OPERATION_ID_REUSE");
    }
    @GetMapping("/latest")
    public LatestChange latest(@AuthenticationPrincipal Jwt jwt,
            @RequestParam String entityType, @RequestParam UUID entityId) {
        return service.latest(owner(jwt), entityType, entityId);
    }

    @GetMapping("/inventory")
    public Inventory inventory(@AuthenticationPrincipal Jwt jwt) {
        return service.inventory(owner(jwt));
    }

    @PostMapping("/reconciliation/check")
    public ReconciliationCheckResponse check(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody ReconciliationCheckRequest request) {
        return service.reconciliationCheck(owner(jwt), request);
    }

    @GetMapping("/changes")
    public Changes changes(@AuthenticationPrincipal Jwt jwt,
                           @RequestParam(defaultValue = "0") @Min(0) long cursor,
                           @RequestParam(defaultValue = "100") @Min(1) @Max(200) int limit) {
        return service.changes(owner(jwt), cursor, limit);
    }
}
