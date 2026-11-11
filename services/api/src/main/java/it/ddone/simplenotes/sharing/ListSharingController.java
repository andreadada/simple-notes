package it.ddone.simplenotes.sharing;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/**
 * Read-only collaboration, separate from the owner-scoped /sync contract.
 * Tokens are supplied in a POST body, never in a query string or GET URL.
 */
@RestController
@RequestMapping("/api/v1/sharing")
public class ListSharingController {
    public record Accept(@NotBlank String token) {}
    public record RoleChange(@NotBlank String role) {}

    private final ListSharingService sharing;
    private final ListSharingEditService edits;
    public ListSharingController(ListSharingService sharing,
            ListSharingEditService edits) {
        this.sharing = sharing;
        this.edits = edits;
    }

    private UUID account(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }

    @PostMapping("/lists/{listId}/invitations")
    public ResponseEntity<ListSharingService.IssuedInvitation> invite(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID listId) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(sharing.issue(account(jwt), listId));
    }

    @GetMapping("/lists/{listId}/invitations")
    public List<ListSharingService.PendingInvitation> invitations(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID listId) {
        return sharing.invitations(account(jwt), listId);
    }

    @DeleteMapping("/lists/{listId}/invitations/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revokeInvitation(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID listId, @PathVariable UUID id) {
        sharing.revokeInvitation(account(jwt), listId, id);
    }

    @PostMapping("/invitations/accept")
    public ListSharingService.SharedList accept(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody Accept input) {
        return sharing.accept(account(jwt), input.token());
    }

    @GetMapping("/lists")
    public List<ListSharingService.SharedList> list(
            @AuthenticationPrincipal Jwt jwt) {
        return sharing.mySharedLists(account(jwt));
    }

    @GetMapping("/lists/{listId}/snapshot")
    public ListSharingService.Snapshot snapshot(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID listId,
            @RequestParam(defaultValue = "0") int offset) {
        return sharing.snapshot(account(jwt), listId, offset);
    }

    @GetMapping("/lists/{listId}/members")
    public List<ListSharingService.Member> members(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID listId) {
        return sharing.members(account(jwt), listId);
    }

    @DeleteMapping("/lists/{listId}/members/{memberId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeMember(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID listId, @PathVariable UUID memberId) {
        sharing.removeMember(account(jwt), listId, memberId);
    }

    @PutMapping("/lists/{listId}/members/{memberId}/role")
    public ListSharingService.Member setRole(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID listId, @PathVariable UUID memberId,
            @Valid @RequestBody RoleChange input) {
        return sharing.setMemberRole(account(jwt), listId, memberId,
            input.role());
    }

    @PatchMapping("/lists/{listId}/tasks/{taskId}")
    public ListSharingEditService.EditedTask editTask(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID listId,
            @PathVariable UUID taskId,
            @Valid @RequestBody ListSharingEditService.EditTask input) {
        return edits.edit(account(jwt), listId, taskId, input);
    }

    @DeleteMapping("/lists/{listId}/membership")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID listId) {
        sharing.leave(account(jwt), listId);
    }
}
