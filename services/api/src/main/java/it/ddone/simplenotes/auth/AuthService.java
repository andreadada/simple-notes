package it.ddone.simplenotes.auth;

import it.ddone.simplenotes.user.*;
import java.nio.charset.StandardCharsets;
import java.net.URI;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService {
    public record AuthResponse(String accessToken, String refreshToken,
        long expiresInSeconds, UUID userId, String displayName, String photoUrl) {}

    private static final Duration ACCESS_TTL = Duration.ofMinutes(15);
    private static final Duration REFRESH_TTL = Duration.ofDays(30);
    private static final SecureRandom RANDOM = new SecureRandom();

    private final JwtDecoder google;
    private final JwtEncoder app;
    private final AppUserRepository users;
    private final RefreshSessionRepository sessions;
    private final String issuer;

    public AuthService(@Qualifier("googleJwtDecoder") JwtDecoder google, JwtEncoder app,
            AppUserRepository users, RefreshSessionRepository sessions,
            @Value("${app.jwt.issuer}") String issuer) {
        this.google = google;
        this.app = app;
        this.users = users;
        this.sessions = sessions;
        this.issuer = issuer;
    }

    @Transactional
    public AuthResponse signIn(String idToken) {
        Jwt identity;
        try { identity = google.decode(idToken); }
        catch (JwtException ex) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid Google ID token");
        }
        if (identity.getSubject() == null || identity.getSubject().isBlank())
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing Google subject");

        String email = identity.getClaimAsString("email");
        Boolean verified = identity.getClaim("email_verified");
        if (email == null || !Boolean.TRUE.equals(verified))
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Verified email is required");

        AppUser user = users.findByGoogleSubject(identity.getSubject())
            .orElseGet(() -> new AppUser(identity.getSubject(), email, identity.getClaimAsString("name")));
        user.email = email;
        user.displayName = identity.getClaimAsString("name");
        String picture = identity.getClaimAsString("picture");
        if (validGooglePhoto(picture)) user.photoUrl = picture;
        users.saveAndFlush(user);
        return issue(user);
    }

    @Transactional
    public AuthResponse refresh(String refreshToken) {
        RefreshSession current = validSession(refreshToken);
        // Lock + rotate: a stolen/replayed refresh token cannot be reused after successful rotation.
        current.revokedAt = Instant.now();
        sessions.saveAndFlush(current);
        AppUser user = users.findById(current.userId).orElseThrow(this::unauthorized);
        return issue(user);
    }

    @Transactional
    public void logout(String refreshToken) {
        // Idempotent logout; do not disclose whether a token exists.
        String hash = sha256(refreshToken);
        sessions.findLockedByHash(hash).ifPresent(session -> {
            session.revokedAt = Instant.now();
            sessions.save(session);
        });
    }

    private RefreshSession validSession(String raw) {
        if (raw == null || raw.isBlank()) throw unauthorized();
        return sessions.findLockedByHash(sha256(raw))
            .filter(s -> s.revokedAt == null && s.expiresAt.isAfter(Instant.now()))
            .orElseThrow(this::unauthorized);
    }

    private ResponseStatusException unauthorized() {
        return new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Session expired or revoked");
    }

    private AuthResponse issue(AppUser user) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer(issuer).subject(user.id.toString()).audience(List.of("simple-notes"))
            .issuedAt(now).expiresAt(now.plus(ACCESS_TTL)).claim("kind", "access").build();
        String access = app.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();

        byte[] random = new byte[32];
        RANDOM.nextBytes(random);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        sessions.save(new RefreshSession(user.id, sha256(refresh), now.plus(REFRESH_TTL)));
        return new AuthResponse(access, refresh, ACCESS_TTL.toSeconds(), user.id, user.displayName, user.photoUrl);
    }

    private static boolean validGooglePhoto(String value) {
        if (value == null || value.isBlank()) return false;
        try {
            URI uri = URI.create(value);
            String host = uri.getHost();
            return "https".equalsIgnoreCase(uri.getScheme())
                && host != null
                && (host.equals("googleusercontent.com") || host.endsWith(".googleusercontent.com"))
                && uri.getUserInfo() == null;
        } catch (IllegalArgumentException exception) {
            return false;
        }
    }

    private static String sha256(String value) {
        try {
            byte[] bytes = MessageDigest.getInstance("SHA-256")
                .digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(bytes);
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
