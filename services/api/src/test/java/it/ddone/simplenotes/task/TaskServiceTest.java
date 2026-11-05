package it.ddone.simplenotes.task;

import com.fasterxml.jackson.databind.ObjectMapper;
import it.ddone.simplenotes.sync.SyncController;
import it.ddone.simplenotes.sync.SyncService;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class TaskServiceTest {
    private final TaskRepository repo = mock(TaskRepository.class);
    private final SyncService sync = mock(SyncService.class);
    private final TaskService service = new TaskService(repo, sync, new ObjectMapper());

    @Test
    void neverReadsTasksBelongingToAnotherUser() {
        UUID owner = UUID.randomUUID(), other = UUID.randomUUID(), taskId = UUID.randomUUID();
        when(repo.findByIdAndOwnerIdAndDeletedAtIsNull(taskId, owner))
            .thenReturn(Optional.empty());
        assertThrows(ResponseStatusException.class,
            () -> service.setCompleted(owner, taskId, true));
        verify(sync).lockAccount(owner);
        verify(sync, never()).apply(any(), any());
        verify(repo, never()).findByIdAndOwnerIdAndDeletedAtIsNull(taskId, other);
    }

    @Test
    void createdTaskIsOwnedAndEmitsCanonicalSyncMutation() {
        UUID owner = UUID.randomUUID();
        when(repo.findById(any(UUID.class))).thenAnswer(call -> {
            UUID id = call.getArgument(0);
            TaskEntity entity = new TaskEntity(owner, "Write docs", null, null);
            entity.id = id;
            return Optional.of(entity);
        });
        TaskEntity result = service.create(owner, "Write docs", null, null);
        assertEquals(owner, result.ownerId);
        assertEquals("Write docs", result.title);
        assertNotNull(result.id);
        verify(sync).apply(eq(owner), argThat((SyncController.ApplyRequest req) ->
            req.entityType().equals("task") &&
            req.action().equals("upsert") &&
            req.entityId().equals(result.id) &&
            req.expectedVersion() == null &&
            req.payload().path("title").asText().equals("Write docs")));
        verify(repo, never()).saveAndFlush(any());
    }

    @Test
    void deleteDelegatesSoftTombstoneToSyncAndNeverHardDeletes() {
        UUID owner = UUID.randomUUID(), taskId = UUID.randomUUID();
        TaskEntity existing = new TaskEntity(owner, "Task", null, null);
        existing.version = 4;
        when(repo.findByIdAndOwnerIdAndDeletedAtIsNull(taskId, owner))
            .thenReturn(Optional.of(existing));
        service.delete(owner, taskId);
        verify(sync).lockAccount(owner);
        verify(sync).apply(eq(owner), argThat((SyncController.ApplyRequest req) ->
            req.entityType().equals("task") &&
            req.action().equals("delete") &&
            req.entityId().equals(taskId) &&
            req.expectedVersion() == 4));
        verify(repo, never()).delete(any(TaskEntity.class));
        verify(repo, never()).saveAndFlush(any());
    }
}
