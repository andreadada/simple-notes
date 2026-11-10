package it.ddone.simplenotes.template;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/** Manual versioned exchange of definitions, never task execution/restore. */
@RestController
@RequestMapping("/api/v1/templates/catalog")
public class UserTemplateCatalogController {
    public record Snapshot(long version, JsonNode catalog) {}
    public record Replace(@NotNull @Min(0) Long expectedVersion,
                          @NotNull JsonNode catalog) {}

    private final UserTemplateCatalogService service;

    public UserTemplateCatalogController(UserTemplateCatalogService service) {
        this.service = service;
    }

    @GetMapping
    public Snapshot read(@AuthenticationPrincipal Jwt jwt) {
        return service.read(UUID.fromString(jwt.getSubject()));
    }

    @PutMapping
    public Snapshot replace(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody Replace request) {
        return service.replace(UUID.fromString(jwt.getSubject()), request);
    }
}
