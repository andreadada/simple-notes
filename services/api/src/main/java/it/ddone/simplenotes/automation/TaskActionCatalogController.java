package it.ddone.simplenotes.automation;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/**
 * Separate from /sync: this is a versioned account preference, not a task
 * mutation and not an instruction to execute an automation on the server.
 */
@RestController
@RequestMapping("/api/v1/automations/task-actions")
public class TaskActionCatalogController {
    public record Snapshot(long version, JsonNode catalog) {}
    public record Replace(@NotNull @Min(0) Long expectedVersion,
        @NotNull JsonNode catalog) {}

    private final TaskActionCatalogService service;

    public TaskActionCatalogController(TaskActionCatalogService service) {
        this.service = service;
    }

    @GetMapping
    public Snapshot read(@AuthenticationPrincipal Jwt jwt) {
        return service.read(UUID.fromString(jwt.getSubject()));
    }

    @PutMapping
    public Snapshot replace(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody Replace body) {
        return service.replace(UUID.fromString(jwt.getSubject()), body);
    }
}
