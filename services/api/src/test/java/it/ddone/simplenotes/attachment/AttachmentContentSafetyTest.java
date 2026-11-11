package it.ddone.simplenotes.attachment;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
import static org.assertj.core.api.Assertions.*;

class AttachmentContentSafetyTest {
    @Test void allowsExpectedMagicBytes() {
        AttachmentContentSafety.requireSupported("image/png", new byte[] {
            (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A});
        AttachmentContentSafety.requireSupported("image/jpeg",
            new byte[] {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0x41});
        AttachmentContentSafety.requireSupported("application/pdf",
            "%PDF-1.7".getBytes(StandardCharsets.US_ASCII));
        AttachmentContentSafety.requireSupported("text/plain",
            "Note\nTest".getBytes(StandardCharsets.UTF_8));
    }
    @Test void rejectsSpoofedContentAndActiveText() {
        for (String type : new String[]{
                "image/png", "image/jpeg", "application/pdf", "text/plain"}) {
            assertThatThrownBy(() ->
                AttachmentContentSafety.requireSupported(type, new byte[]{0, 1, 2}))
                .isInstanceOf(ResponseStatusException.class);
            assertThatThrownBy(() ->
                AttachmentContentSafety.requireSupported(type, null))
                .isInstanceOf(ResponseStatusException.class);
        }
        for (String html : new String[]{
                "<html>hello</html>", " <!DOCTYPE html>", "<svg onload='x'>",
                "<script>alert(1)</script>", "<?xml version='1.0'?>"}) {
            assertThatThrownBy(() ->
                AttachmentContentSafety.requireSupported("text/plain",
                    html.getBytes(StandardCharsets.UTF_8)))
                .isInstanceOf(ResponseStatusException.class);
        }
    }
}
