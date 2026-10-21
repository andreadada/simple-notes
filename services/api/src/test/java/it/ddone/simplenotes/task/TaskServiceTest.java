package it.ddone.simplenotes.task;

import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class TaskServiceTest {
    private final TaskRepository repo = mock(TaskRepository.class);
    private final TaskService service = new TaskService(repo);

    @Test
    void neverReadsTasksBelongingToAnotherUser() {
        UUID owner = UUID.randomUUID(), other = UUID.randomUUID(), taskId = UUID.randomUUID();
        when(repo.findByIdAndOwnerIdAndDeletedAtIsNull(taskId, owner)).thenReturn(Optional.empty());
        assertThrows(ResponseStatusException.class, () -> service.setCompleted(owner, taskId, true));
        verify(repo, never()).save(any());
        verify(repo, never()).findByIdAndOwnerIdAndDeletedAtIsNull(taskId, other);
    }

    @Test
    void createdTaskIsOwnedByAuthenticatedUser() {
        UUID owner = UUID.randomUUID();
        TaskEntity expected = new TaskEntity(owner, "Write docs", null, null);
        when(repo.save(any(TaskEntity.class))).thenAnswer(call -> call.getArgument(0));
        TaskEntity result = service.create(owner, "Write docs", null, null);
        assertEquals(owner, result.ownerId);
        assertEquals("Write docs", result.title);
        assertNotNull(result.id);
    }

    @Test
    void deleteIsSoftDeleteAndNeverErasesTask() {
        UUID owner = UUID.randomUUID(), taskId = UUID.randomUUID();
        TaskEntity existing = new TaskEntity(owner, "Task", null, null);
        when(repo.findByIdAndOwnerIdAndDeletedAtIsNull(taskId, owner)).thenReturn(Optional.of(existing));
        service.delete(owner, taskId);
        assertNotNull(existing.deletedAt);
        verify(repo).save(existing);
        verify(repo, never()).delete(any(TaskEntity.class));
    }
}
