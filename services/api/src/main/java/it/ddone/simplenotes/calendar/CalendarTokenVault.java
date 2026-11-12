package it.ddone.simplenotes.calendar;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.UUID;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/** AES-256-GCM with owner/provider/purpose AAD; no plaintext tokens in SQL. */
@Component
public final class CalendarTokenVault {
    private static final SecureRandom RANDOM = new SecureRandom();
    private final CalendarOAuthConfig config;

    public CalendarTokenVault(CalendarOAuthConfig config) { this.config = config; }

    private static byte[] aad(UUID owner, String provider, String purpose) {
        return (owner + "|" + provider + "|" + purpose).getBytes(StandardCharsets.UTF_8);
    }

    public String seal(String plaintext, UUID owner, String provider, String purpose) {
        try {
            byte[] nonce = new byte[12];
            RANDOM.nextBytes(nonce);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(config.encryptionKey(), "AES"),
                new GCMParameterSpec(128, nonce));
            cipher.updateAAD(aad(owner, provider, purpose));
            byte[] encrypted = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
            byte[] combined = new byte[nonce.length + encrypted.length];
            System.arraycopy(nonce, 0, combined, 0, nonce.length);
            System.arraycopy(encrypted, 0, combined, nonce.length, encrypted.length);
            return Base64.getUrlEncoder().withoutPadding().encodeToString(combined);
        } catch (Exception ex) { throw new IllegalStateException("Calendar vault encryption failed", ex); }
    }

    public String open(String encoded, UUID owner, String provider, String purpose) {
        try {
            byte[] combined = Base64.getUrlDecoder().decode(encoded);
            if (combined.length < 29) throw new IllegalArgumentException("Ciphertext too short");
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(config.encryptionKey(), "AES"),
                new GCMParameterSpec(128, combined, 0, 12));
            cipher.updateAAD(aad(owner, provider, purpose));
            return new String(cipher.doFinal(combined, 12, combined.length - 12),
                StandardCharsets.UTF_8);
        } catch (Exception ex) { throw new IllegalStateException("Calendar vault integrity check failed"); }
    }
}
