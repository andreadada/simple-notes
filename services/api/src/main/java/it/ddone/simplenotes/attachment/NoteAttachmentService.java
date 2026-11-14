package it.ddone.simplenotes.attachment;

import it.ddone.simplenotes.note.NoteRepository;
import it.ddone.simplenotes.sync.SyncService;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class NoteAttachmentService {
    private static final long MAX_FILE = 10L * 1024 * 1024;
    private static final long MAX_OWNER_BYTES = 200L * 1024 * 1024;
    private static final Set<String> TYPES = Set.of(
        "image/png", "image/jpeg", "application/pdf", "text/plain");
    private final NoteAttachmentRepository attachments;
    private final NoteRepository notes;
    private final AttachmentObjectStore objects;
    private final SyncService sync;
    private final AttachmentDeletionQueue deletionQueue;
    private final AttachmentMalwareScanner malwareScanner;

    public NoteAttachmentService(NoteAttachmentRepository attachments,
            NoteRepository notes, AttachmentObjectStore objects, SyncService sync,
            AttachmentDeletionQueue deletionQueue,
            AttachmentMalwareScanner malwareScanner) {
        this.attachments = attachments;
        this.notes = notes;
        this.objects = objects;
        this.sync = sync;
        this.deletionQueue = deletionQueue;
        this.malwareScanner = malwareScanner;
    }

    private void ownedNote(UUID owner, UUID note) {
        if (notes.findByIdAndOwnerIdAndDeletedAtIsNull(note, owner).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Note not found");
        }
    }

    @Transactional(readOnly = true)
    public List<NoteAttachmentEntity> list(UUID owner, UUID note) {
        ownedNote(owner, note);
        return attachments.findByOwnerIdAndNoteIdAndStateOrderByCreatedAtDesc(
            owner, note, "READY");
    }

    @Transactional
    public NoteAttachmentController.Upload begin(UUID owner, UUID note,
            NoteAttachmentController.Begin input) {
        sync.lockAccount(owner);
        ownedNote(owner, note);
        String name = input.name();
        if (!name.equals(name.trim()) || name.isBlank() ||
                name.indexOf('/') >= 0 || name.indexOf('\\') >= 0 ||
                name.chars().anyMatch(c -> c < 32 || c == 127) ||
                name.equals(".") || name.equals("..") ||
                !TYPES.contains(input.contentType()) ||
                input.sizeBytes() < 1 || input.sizeBytes() > MAX_FILE) {
            throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST, "Unsupported attachment");
        }
        malwareScanner.requireConfigured();
        Instant now = Instant.now();
        if (attachments.activeCount(owner, now) >= 100 ||
            attachments.activeBytes(owner, now) > MAX_OWNER_BYTES - input.sizeBytes()) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Attachment account quota exceeded");
        }
        var record = new NoteAttachmentEntity(
            owner, note, name, input.contentType(), input.sizeBytes(), now);
        var ticket = objects.presignPut(
            record.objectKey, record.contentType, record.sizeBytes);
        attachments.saveAndFlush(record);
        return new NoteAttachmentController.Upload(
            record.id, ticket.url(), ticket.headers(), now.plusSeconds(300));
    }

    @Transactional
    public NoteAttachmentEntity complete(UUID owner, UUID note, UUID id) {
        sync.lockAccount(owner);
        ownedNote(owner, note);
        var attachment = find(owner, note, id);
        if ("READY".equals(attachment.state)) return attachment;
        if (Instant.now().isAfter(attachment.pendingExpiresAt)) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Attachment upload window expired");
        }
        var actual = objects.inspect(attachment.objectKey);
        if (actual.bytes() != attachment.sizeBytes ||
            !attachment.contentType.equals(actual.contentType()) ||
            actual.etag() == null || actual.etag().isBlank()) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT, "Attachment size/type mismatch");
        }
        // A signed upload URL can send arbitrary bytes regardless of its MIME
        // header. Verify a conditional range GET before the ETag-guarded COPY.
        AttachmentContentSafety.requireSupported(attachment.contentType,
            objects.readPrefix(attachment.objectKey, actual.etag(), 512));
        // Scan all bytes, not only the MIME/header prefix, before promoting
        // to a permanent S3 key or changing READY metadata.
        byte[] full = objects.readForScan(attachment.objectKey, actual.etag(),
            Math.toIntExact(attachment.sizeBytes));
        if (full == null || full.length != attachment.sizeBytes) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Attachment changed during full malware inspection");
        }
        malwareScanner.scan(full);
        String readyKey = "files/" + owner + "/" + attachment.id;
        objects.promote(attachment.objectKey, readyKey,
            attachment.contentType, actual.etag());
        attachment.objectKey = readyKey;
        attachment.state = "READY";
        return attachments.saveAndFlush(attachment);
    }

    @Transactional(readOnly = true)
    public NoteAttachmentController.Download download(UUID owner, UUID note, UUID id) {
        ownedNote(owner, note);
        var attachment = find(owner, note, id);
        if (!"READY".equals(attachment.state)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
        return new NoteAttachmentController.Download(
            objects.presignGet(attachment.objectKey), Instant.now().plusSeconds(300));
    }

    @Transactional
    public void delete(UUID owner, UUID note, UUID id) {
        sync.lockAccount(owner);
        ownedNote(owner, note);
        var attachment = find(owner, note, id);
        if ("READY".equals(attachment.state)) {
            // Queue in the SAME database transaction as metadata removal.
            // Never delete S3 before the database commit: a rollback must
            // leave a readable object rather than a broken READY record.
            deletionQueue.enqueue(owner, attachment.objectKey);
        }
        attachments.delete(attachment);
        attachments.flush();
    }

    private NoteAttachmentEntity find(UUID owner, UUID note, UUID id) {
        return attachments.findByIdAndOwnerIdAndNoteId(id, owner, note)
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Attachment not found"));
    }
}
