package it.ddone.simplenotes.calendar;

import java.net.URI;
import java.util.Base64;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Dedicated provider grants, independent of the Simple Notes sign-in. */
@Component
public final class CalendarOAuthConfig {
    public record Credentials(String id, String secret) {
        boolean complete() { return !id.isBlank() && !secret.isBlank(); }
    }

    private final URI publicOrigin;
    private final Map<String, Credentials> credentials;
    private final byte[] encryptionKey;

    public CalendarOAuthConfig(
            @Value("$" + "{app.calendar.public-origin:}") String origin,
            @Value("$" + "{app.calendar.token-key-base64:}") String encodedKey,
            @Value("$" + "{app.calendar.google-client-id:}") String googleId,
            @Value("$" + "{app.calendar.google-client-secret:}") String googleSecret,
            @Value("$" + "{app.calendar.microsoft-client-id:}") String microsoftId,
            @Value("$" + "{app.calendar.microsoft-client-secret:}") String microsoftSecret) {
        credentials = Map.of("google", new Credentials(googleId.trim(), googleSecret.trim()),
            "microsoft", new Credentials(microsoftId.trim(), microsoftSecret.trim()));
        boolean any = credentials.values().stream().anyMatch(Credentials::complete);
        if (any) {
            if (origin.isBlank()) throw new IllegalStateException("Calendar public origin required");
            URI parsed = URI.create(origin);
            if (!"https".equals(parsed.getScheme()) || parsed.getHost() == null
                    || parsed.getUserInfo() != null || parsed.getPort() != -1
                    || (parsed.getPath() != null && !parsed.getPath().isEmpty() && !parsed.getPath().equals("/"))
                    || parsed.getQuery() != null || parsed.getFragment() != null) {
                throw new IllegalStateException("Calendar callback must use one fixed HTTPS origin");
            }
            publicOrigin = URI.create("https://" + parsed.getHost());
            byte[] decoded;
            try { decoded = Base64.getDecoder().decode(encodedKey); }
            catch (IllegalArgumentException ex) { throw new IllegalStateException("Invalid calendar token key"); }
            if (decoded.length != 32) throw new IllegalStateException("Calendar token key must be 32 bytes");
            encryptionKey = decoded.clone();
        } else {
            publicOrigin = null;
            encryptionKey = null;
        }
    }

    public boolean available(String provider) {
        return credentials.containsKey(provider) && publicOrigin != null
            && credentials.get(provider).complete();
    }

    public Credentials require(String provider) {
        Credentials c = credentials.get(provider);
        if (c == null) throw new IllegalArgumentException("Unknown calendar provider");
        if (!available(provider)) throw new IllegalStateException("Calendar provider not configured");
        return c;
    }

    public String callback(String provider) {
        require(provider);
        return publicOrigin + "/api/v1/calendars/oauth/" + provider + "/callback";
    }

    public byte[] encryptionKey() {
        if (encryptionKey == null) throw new IllegalStateException("Calendar vault not configured");
        return encryptionKey.clone();
    }
}
