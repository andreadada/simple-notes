package it.ddone.simplenotes.calendar;

import com.fasterxml.jackson.databind.JsonNode;
import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * One-time, account-bound PKCE consent with separate provider grants.
 * Provider tokens are never returned in any Simple Notes API response.
 */
@Service
public class CalendarOAuthService {
    public record ProviderStatus(String provider, boolean available, boolean connected) {}
    public record Authorization(String authorizationUrl, Instant expiresAt) {}
    private record Attempt(UUID owner, String provider, String encryptedVerifier, Instant expiresAt) {}
    private record Link(String encryptedAccess, String encryptedRefresh, Instant expiresAt) {}
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final List<String> PROVIDERS = List.of("google", "microsoft");

    private final JdbcTemplate jdbc;
    private final CalendarOAuthConfig config;
    private final CalendarTokenVault vault;
    private final CalendarHttpGateway http;

    public CalendarOAuthService(JdbcTemplate jdbc, CalendarOAuthConfig config,
            CalendarTokenVault vault, CalendarHttpGateway http) {
        this.jdbc = jdbc; this.config = config; this.vault = vault; this.http = http;
    }

    static String randomToken() {
        byte[] random = new byte[32];
        RANDOM.nextBytes(random);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(random);
    }

    static String digest(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception ex) { throw new IllegalStateException(ex); }
    }

    static String challenge(String verifier) {
        try {
            return Base64.getUrlEncoder().withoutPadding().encodeToString(
                MessageDigest.getInstance("SHA-256")
                    .digest(verifier.getBytes(StandardCharsets.US_ASCII)));
        } catch (Exception ex) { throw new IllegalStateException(ex); }
    }

    static URI uri(String endpoint, Map<String, String> params) {
        return URI.create(endpoint + "?" + CalendarHttpGateway.form(params));
    }

    private CalendarOAuthConfig.Credentials require(String provider) {
        if (!PROVIDERS.contains(provider)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Unknown calendar provider");
        }
        if (!config.available(provider)) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                "Calendar provider not configured");
        }
        return config.require(provider);
    }

    public List<ProviderStatus> status(UUID owner) {
        List<ProviderStatus> result = new ArrayList<>();
        for (String provider : PROVIDERS) {
            boolean connected = !jdbc.query(
                "SELECT provider FROM calendar_oauth_connection WHERE owner_id=? AND provider=?",
                (rs, n) -> rs.getString(1), owner, provider).isEmpty();
            result.add(new ProviderStatus(provider, config.available(provider), connected));
        }
        return result;
    }

    @Transactional
    public Authorization begin(UUID owner, String provider) {
        var credentials = require(provider);
        String state = randomToken(), verifier = randomToken();
        Instant expires = Instant.now().plusSeconds(600);
        // One pending flow per owner/provider; old flow becomes unusable.
        jdbc.update("DELETE FROM calendar_oauth_attempt WHERE owner_id=? AND provider=?",
            owner, provider);
        jdbc.update("INSERT INTO calendar_oauth_attempt"
                + "(state_hash,owner_id,provider,verifier_encrypted,expires_at) VALUES(?,?,?,?,?)",
            digest(state), owner, provider,
            vault.seal(verifier, owner, provider, "pkce"), java.sql.Timestamp.from(expires));

        Map<String,String> query = new LinkedHashMap<>();
        query.put("client_id", credentials.id());
        query.put("redirect_uri", config.callback(provider));
        query.put("response_type", "code");
        query.put("state", state);
        query.put("code_challenge", challenge(verifier));
        query.put("code_challenge_method", "S256");
        if ("google".equals(provider)) {
            query.put("scope", "https://www.googleapis.com/auth/calendar.events.readonly");
            query.put("access_type", "offline");
            query.put("prompt", "consent");
        } else {
            query.put("scope", "offline_access Calendars.Read");
            query.put("response_mode", "query");
        }
        String endpoint = "google".equals(provider)
            ? "https://accounts.google.com/o/oauth2/v2/auth"
            : "https://login.microsoftonline.com/common/oauth2/v2.0/authorize";
        return new Authorization(uri(endpoint, query).toString(), expires);
    }

    /**
     * The callback has no application JWT: the random, hashed and consumed state
     * is its only account binding. No arbitrary redirect target is accepted.
     */
    public void complete(String provider, String state, String code, String error) {
        require(provider);
        if (state == null || !state.matches("[A-Za-z0-9_-]{43}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid OAuth state");
        }
        List<Attempt> attempts = jdbc.query(
            "DELETE FROM calendar_oauth_attempt WHERE state_hash=? AND provider=? "
                + "RETURNING owner_id,provider,verifier_encrypted,expires_at",
            (rs,n) -> new Attempt(rs.getObject("owner_id", UUID.class),
                rs.getString("provider"), rs.getString("verifier_encrypted"),
                rs.getTimestamp("expires_at").toInstant()),
            digest(state), provider);
        if (attempts.size() != 1 || !attempts.get(0).expiresAt().isAfter(Instant.now())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "OAuth state expired or already used");
        }
        if (error != null || code == null || code.isBlank() || code.length() > 4096) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Calendar consent cancelled");
        }
        Attempt attempt = attempts.get(0);
        var credentials = config.require(provider);
        Map<String, String> params = new LinkedHashMap<>();
        params.put("client_id", credentials.id());
        params.put("client_secret", credentials.secret());
        params.put("code", code);
        params.put("redirect_uri", config.callback(provider));
        params.put("grant_type", "authorization_code");
        params.put("code_verifier", vault.open(attempt.encryptedVerifier(),
            attempt.owner(), provider, "pkce"));
        JsonNode tokens = http.token(tokenEndpoint(provider), params);
        String access = tokens.path("access_token").asText("");
        String refresh = tokens.path("refresh_token").asText("");
        long ttl = tokens.path("expires_in").asLong(0);
        if (access.isEmpty() || refresh.isEmpty() || ttl < 60 || ttl > 604800) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                "Provider did not return a renewable calendar grant");
        }
        jdbc.update("INSERT INTO calendar_oauth_connection"
            + "(owner_id,provider,access_token_encrypted,refresh_token_encrypted,expires_at)"
            + " VALUES (?,?,?,?,?) ON CONFLICT(owner_id,provider) DO UPDATE SET"
            + " access_token_encrypted=EXCLUDED.access_token_encrypted,"
            + " refresh_token_encrypted=EXCLUDED.refresh_token_encrypted,"
            + " expires_at=EXCLUDED.expires_at, updated_at=now()",
            attempt.owner(), provider,
            vault.seal(access, attempt.owner(), provider, "access"),
            vault.seal(refresh, attempt.owner(), provider, "refresh"),
            java.sql.Timestamp.from(Instant.now().plusSeconds(ttl)));
    }

    static URI tokenEndpoint(String provider) {
        return URI.create("google".equals(provider)
            ? "https://oauth2.googleapis.com/token"
            : "https://login.microsoftonline.com/common/oauth2/v2.0/token");
    }

    @Transactional
    public void disconnect(UUID owner, String provider) {
        // Disconnect must work even after an administrator disables credentials.
        if (!PROVIDERS.contains(provider)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Unknown calendar provider");
        }
        jdbc.update("DELETE FROM calendar_oauth_attempt WHERE owner_id=? AND provider=?",
            owner, provider);
        jdbc.update("DELETE FROM calendar_oauth_connection WHERE owner_id=? AND provider=?",
            owner, provider);
    }

    private Link link(UUID owner, String provider) {
        var records = jdbc.query("SELECT access_token_encrypted, refresh_token_encrypted,"
                + " expires_at FROM calendar_oauth_connection WHERE owner_id=? AND provider=?",
            (rs,n) -> new Link(rs.getString(1), rs.getString(2),
                rs.getTimestamp(3).toInstant()), owner, provider);
        if (records.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                "Calendar provider not linked");
        }
        return records.get(0);
    }

    public String bearer(UUID owner, String provider) {
        var credentials = require(provider);
        Link current = link(owner, provider);
        if (current.expiresAt().isAfter(Instant.now().plusSeconds(90))) {
            return vault.open(current.encryptedAccess(), owner, provider, "access");
        }
        Map<String,String> params = new LinkedHashMap<>();
        params.put("client_id", credentials.id());
        params.put("client_secret", credentials.secret());
        params.put("grant_type", "refresh_token");
        params.put("refresh_token",
            vault.open(current.encryptedRefresh(), owner, provider, "refresh"));
        JsonNode tokens = http.token(tokenEndpoint(provider), params);
        String access = tokens.path("access_token").asText("");
        String refresh = tokens.path("refresh_token").asText("");
        long ttl = tokens.path("expires_in").asLong(0);
        if (access.isBlank() || ttl < 60 || ttl > 604800) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                "Calendar session needs reconnection");
        }
        String nextRefresh = refresh.isBlank()
            ? vault.open(current.encryptedRefresh(), owner, provider, "refresh") : refresh;
        String encrypted = vault.seal(access, owner, provider, "access");
        int updated = jdbc.update("UPDATE calendar_oauth_connection SET"
                + " access_token_encrypted=?,refresh_token_encrypted=?,"
                + " expires_at=?,updated_at=now() WHERE owner_id=? AND provider=?"
                + " AND access_token_encrypted=?",
            encrypted, vault.seal(nextRefresh, owner, provider, "refresh"),
            java.sql.Timestamp.from(Instant.now().plusSeconds(ttl)),
            owner, provider, current.encryptedAccess());
        // Do not recreate a link after disconnect, or clobber a concurrent refresh.
        return updated == 1 ? access
            : vault.open(link(owner, provider).encryptedAccess(), owner, provider, "access");
    }
}
