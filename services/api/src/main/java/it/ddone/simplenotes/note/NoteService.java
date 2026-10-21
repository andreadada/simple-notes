package it.ddone.simplenotes.note;

import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class NoteService {
    private final NoteRepository repository;
    public NoteService(NoteRepository repository) { this.repository = repository; }

    @Transactional(readOnly = true)
    public List<NoteEntity> all(UUID owner) {
        return repository.findByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(owner);
    }

    @Transactional
    public NoteEntity create(UUID owner, String title, String body) {
        return repository.saveAndFlush(new NoteEntity(owner, title, body));
    }

    @Transactional
    public NoteEntity update(UUID owner, UUID id, long expectedVersion, String title, String body) {
        NoteEntity note = owned(owner, id);
        if (note.version != expectedVersion)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Version conflict");
        note.title = title;
        note.body = body;
        note.updatedAt = Instant.now();
        return repository.saveAndFlush(note);
    }

    @Transactional
    public void delete(UUID owner, UUID id, long expectedVersion) {
        NoteEntity note = owned(owner, id);
        if (note.version != expectedVersion)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Version conflict");
        note.deletedAt = note.updatedAt = Instant.now();
        repository.saveAndFlush(note);
    }

    private NoteEntity owned(UUID owner, UUID id) {
        return repository.findByIdAndOwnerIdAndDeletedAtIsNull(id, owner)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Note not found"));
    }
}
