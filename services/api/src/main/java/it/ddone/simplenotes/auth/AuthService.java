package it.ddone.simplenotes.auth;

import it.ddone.simplenotes.user.*;
import java.time.Duration;
import java.time.Instant;
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
    public record AuthResponse(String accessToken, long expiresInSeconds, UUID userId, String displayName) {}
    private static final Duration ACCESS_TTL = Duration.ofMinutes(15);
    private final JwtDecoder google;
    private final JwtEncoder app;
    private final AppUserRepository users;
    private final String issuer;

    public AuthService(@Qualifier("googleJwtDecoder") JwtDecoder google, JwtEncoder app,
            AppUserRepository users, @Value("${app.jwt.issuer}") String issuer) {
        this.google = google;
        this.app = app;
        this.users = users;
        this.issuer = issuer;
    }

    @Transactional
    public AuthResponse signIn(String idToken) {
        Jwt identity;
        try { identity = google.decode(idToken); }
        catch (JwtException ex) { throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid Google ID token"); }
        if (identity.getSubject() == null || identity.getSubject().isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing Google subject");
        }
        String email = identity.getClaimAsString("email");
        Boolean verified = identity.getClaim("email_verified");
        if (email == null || !Boolean.TRUE.equals(verified)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Verified email is required");
        }
        AppUser user = users.findByGoogleSubject(identity.getSubject())
            .orElseGet(() -> new AppUser(identity.getSubject(), email, identity.getClaimAsString("name")));
        user.email = email;
        user.displayName = identity.getClaimAsString("name");
        users.save(user);
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer(issuer).subject(user.id.toString()).audience(java.util.List.of("simple-notes"))
            .issuedAt(now).expiresAt(now.plus(ACCESS_TTL)).claim("kind", "access").build();
        String token = app.encode(JwtEncoderParameters.from(
            JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
        return new AuthResponse(token, ACCESS_TTL.toSeconds(), user.id, user.displayName);
    }
}
