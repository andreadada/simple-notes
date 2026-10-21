package it.ddone.simplenotes.note;

import java.time.Instant;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/notes")
public class NoteController {
    public record Create(@NotBlank @Size(max = 255) String title, @NotNull String body) {}
    public record Update(@NotNull @Min(0) Long version,
        @NotBlank @Size(max = 255) String title, @NotNull String body) {}
    public record View(UUID id, String title, String body, long version, Instant updatedAt) {
        static View from(NoteEntity note) {
            return new View(note.id, note.title, note.body, note.version, note.updatedAt);
        }
    }

    private final NoteService notes;
    public NoteController(NoteService notes) { this.notes = notes; }
    private UUID owner(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }

    @GetMapping
    public List<View> list(@AuthenticationPrincipal Jwt jwt) {
        return notes.all(owner(jwt)).stream().map(View::from).toList();
    }
    @PostMapping
    public ResponseEntity<View> create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody Create value) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(View.from(notes.create(owner(jwt), value.title(), value.body())));
    }
    @PutMapping("/{id}")
    public View update(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, @Valid @RequestBody Update value) {
        return View.from(notes.update(owner(jwt), id, value.version(), value.title(), value.body()));
    }
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, @RequestParam long version) {
        notes.delete(owner(jwt), id, version);
    }
}
