package it.ddone.simplenotes.task;

import java.time.Instant;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/tasks")
public class TaskController {
    public record CreateTask(@NotBlank @Size(max = 1024) String title, String description, Instant dueAt) {}
    public record CompletionRequest(boolean completed) {}
    public record TaskView(UUID id, String title, String description, Instant dueAt, Instant completedAt, long version) {
        static TaskView from(TaskEntity t) {
            return new TaskView(t.id, t.title, t.description, t.dueAt, t.completedAt, t.version);
        }
    }
    private final TaskService tasks;
    public TaskController(TaskService tasks) { this.tasks = tasks; }
    private UUID owner(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }

    @GetMapping
    public List<TaskView> list(@AuthenticationPrincipal Jwt jwt) {
        return tasks.all(owner(jwt)).stream().map(TaskView::from).toList();
    }

    @PostMapping
    public ResponseEntity<TaskView> create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody CreateTask request) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(TaskView.from(tasks.create(owner(jwt), request.title(), request.description(), request.dueAt())));
    }

    @PatchMapping("/{id}/completion")
    public TaskView complete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, @RequestBody CompletionRequest request) {
        return TaskView.from(tasks.setCompleted(owner(jwt), id, request.completed()));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        tasks.delete(owner(jwt), id);
    }
}
