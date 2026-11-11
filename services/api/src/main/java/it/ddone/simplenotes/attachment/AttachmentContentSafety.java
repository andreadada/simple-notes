package it.ddone.simplenotes.attachment;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Defense in depth on the beginning of each uploaded object, not an antivirus
 * scanner. Called only after a conditional S3 range GET against the HEAD ETag.
 */
final class AttachmentContentSafety {
    private static final byte[] PNG = {
        (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    };
    private static final byte[] PDF = "%PDF-".getBytes(StandardCharsets.US_ASCII);

    private AttachmentContentSafety() {}

    static void requireSupported(String type, byte[] prefix) {
        boolean valid = prefix != null && prefix.length > 0 && switch (type) {
            case "image/png" -> startsWith(prefix, PNG);
            case "image/jpeg" -> prefix.length >= 3 &&
                (prefix[0] & 0xFF) == 0xFF &&
                (prefix[1] & 0xFF) == 0xD8 &&
                (prefix[2] & 0xFF) == 0xFF;
            case "application/pdf" -> startsWith(prefix, PDF);
            case "text/plain" -> isPlainText(prefix);
            default -> false;
        };
        if (!valid) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Attachment content does not match allowed type");
        }
    }

    private static boolean startsWith(byte[] input, byte[] signature) {
        return input.length >= signature.length &&
            Arrays.equals(input, 0, signature.length,
                signature, 0, signature.length);
    }

    private static boolean isPlainText(byte[] input) {
        for (byte value : input) {
            int c = value & 0xFF;
            if (c == 0 || (c < 32 && c != 9 && c != 10 && c != 13)
                    || c == 127) return false;
        }
        // Do not permit obvious active-content documents to bypass the
        // MIME allowlist by claiming text/plain. This is not HTML sanitizing.
        String start = new String(input, StandardCharsets.UTF_8)
            .replace("\uFEFF", "").stripLeading().toLowerCase(Locale.ROOT);
        return !start.startsWith("<html") &&
            !start.startsWith("<!doctype html") &&
            !start.startsWith("<script") &&
            !start.startsWith("<svg") &&
            !start.startsWith("<?xml");
    }
}
