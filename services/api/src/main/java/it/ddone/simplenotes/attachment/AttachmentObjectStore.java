package it.ddone.simplenotes.attachment;

import java.util.Map;

/** External object operations are isolated for tests and S3-compatible hosts. */
public interface AttachmentObjectStore extends AutoCloseable {
    record Ticket(String url, Map<String, String> headers) {}
    record Metadata(long bytes, String contentType, String etag) {}
    Ticket presignPut(String key, String contentType, long bytes);
    Metadata inspect(String key);
    /** Range GET conditional on the HEAD ETag: reject a changed staging object. */
    byte[] readPrefix(String key, String expectedEtag, int maxBytes);
    /** Conditional, bounded full-file read for malware scanning before COPY. */
    byte[] readForScan(String key, String expectedEtag, int expectedBytes);
    void promote(String stagingKey, String permanentKey, String contentType,
        String expectedEtag);
    String presignGet(String permanentKey);
    void delete(String permanentKey);
    @Override default void close() {}
}
