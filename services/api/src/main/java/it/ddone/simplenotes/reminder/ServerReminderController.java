package it.ddone.simplenotes.reminder;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/reminders/server")
public class ServerReminderController {
    public record Settings(@NotNull Boolean enabled,
        @NotNull Integer leadMinutes,@NotNull @Min(0) Long expectedVersion) {}

    private final ServerReminderService service;
    public ServerReminderController(ServerReminderService service) {
        this.service=service;
    }
    private static UUID owner(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }

    @GetMapping("/preferences")
    public ServerReminderService.Preferences preferences(@AuthenticationPrincipal Jwt jwt) {
        return service.preferences(owner(jwt));
    }

    @PutMapping("/preferences")
    public ServerReminderService.Preferences configure(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody Settings settings) {
        return service.configure(owner(jwt),settings.enabled(),
            settings.leadMinutes(),settings.expectedVersion());
    }

    @GetMapping("/occurrences")
    public List<ServerReminderService.Occurrence> unread(@AuthenticationPrincipal Jwt jwt) {
        return service.unread(owner(jwt));
    }

    @PostMapping("/occurrences/{id}/ack")
    public ResponseEntity<Void> acknowledge(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID id) {
        service.acknowledge(owner(jwt),id);
        return ResponseEntity.noContent().build();
    }
}
