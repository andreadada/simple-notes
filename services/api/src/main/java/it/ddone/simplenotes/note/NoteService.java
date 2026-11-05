package it.ddone.simplenotes.note;

import com.fasterxml.jackson.databind.ObjectMapper;
import it.ddone.simplenotes.sync.SyncController;
import it.ddone.simplenotes.sync.SyncService;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Compatibility REST API. Every mutation goes through SyncService.apply so
 * legacy clients participate in the SAME owner advisory lock, per-record
 * version check and change ledger as Flutter clients.
 *
 * Existing endpoints, request shapes and response shapes stay unchanged.
 * The legacy caller does not supply an operation ID: mint one per REST call.
 */
@Service
public class NoteService {
    private final NoteRepository repository;
    private final SyncService sync;
    private final ObjectMapper json;

    public NoteService(NoteRepository repository, SyncService sync,
            ObjectMapper json) {
        this.repository = repository;
        this.sync = sync;
        this.json = json;
    }

    @Transactional(readOnly = true)
    public List<NoteEntity> all(UUID owner) {
        return repository.findByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(owner);
    }

    @Transactional
    public NoteEntity create(UUID owner, String title, String body) {
        UUID id = UUID.randomUUID();
        sync.apply(owner, new SyncController.ApplyRequest(UUID.randomUUID(), id,
            "note", "upsert", null,
            json.valueToTree(Map.of("title", title, "body", body)), null));
        return repository.findById(id).orElseThrow();
    }

    @Transactional
    public NoteEntity update(UUID owner, UUID id, long expectedVersion,
            String title, String body) {
        sync.lockAccount(owner);
        // Preserve legacy 404 semantics for an absent/foreign/trashed note.
        owned(owner, id);
        sync.apply(owner, new SyncController.ApplyRequest(UUID.randomUUID(), id,
            "note", "upsert", expectedVersion,
            json.valueToTree(Map.of("title", title, "body", body)), null));
        return repository.findById(id).orElseThrow();
    }

    @Transactional
    public void delete(UUID owner, UUID id, long expectedVersion) {
        sync.lockAccount(owner);
        owned(owner, id);
        sync.apply(owner, new SyncController.ApplyRequest(UUID.randomUUID(), id,
            "note", "delete", expectedVersion, null, null));
    }

    private NoteEntity owned(UUID owner, UUID id) {
        return repository.findByIdAndOwnerIdAndDeletedAtIsNull(id, owner)
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Note not found"));
    }
}
