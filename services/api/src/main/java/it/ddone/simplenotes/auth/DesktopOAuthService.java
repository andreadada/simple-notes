package it.ddone.simplenotes.auth;

import java.net.URI;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.server.ResponseStatusException;

@Service
public class DesktopOAuthService {
    private final String clientId;
    private final String clientSecret;
    private final RestClient googleToken;
    private final AuthService auth;

    public DesktopOAuthService(@Value("${app.google.desktop-client-id:}") String clientId,
            @Value("${app.google.desktop-client-secret:}") String clientSecret, AuthService auth) {
        this.clientId = clientId;
        this.clientSecret = clientSecret;
        this.auth = auth;
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(10000);
        factory.setReadTimeout(10000);
        googleToken = RestClient.builder()
            .requestFactory(factory)
            .baseUrl("https://oauth2.googleapis.com")
            .build();
    }

    public AuthService.AuthResponse exchange(String code, String verifier, String redirectUri) {
        if (clientId.isBlank() || clientSecret.isBlank())
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Desktop Google OAuth not configured");
        if (code == null || code.isBlank() || verifier == null ||
            !verifier.matches("[A-Za-z0-9\\-._~]{43,128}") || !validRedirect(redirectUri))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid OAuth callback or verifier");

        var body = new LinkedMultiValueMap<String, String>();
        body.add("grant_type", "authorization_code");
        body.add("client_id", clientId);
        // Keep desktop client_secret on the server, never bundle it with the client.
        body.add("client_secret", clientSecret);
        body.add("code", code);
        body.add("code_verifier", verifier);
        body.add("redirect_uri", redirectUri);

        try {
            Map<?, ?> token = googleToken.post().uri("/token")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(body).retrieve().body(Map.class);
            Object idToken = token == null ? null : token.get("id_token");
            if (!(idToken instanceof String s) || s.isBlank())
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Google ID token not returned");
            return auth.signIn(s);
        } catch (RestClientException e) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Google code exchange failed");
        }
    }

    static boolean validRedirect(String raw) {
        try {
            URI uri = URI.create(raw);
            return "http".equals(uri.getScheme())
                && "127.0.0.1".equals(uri.getHost())
                && uri.getPort() > 0
                && "/oauth/callback".equals(uri.getPath())
                && uri.getRawQuery() == null
                && uri.getRawFragment() == null
                && uri.getUserInfo() == null;
        } catch (RuntimeException ex) {
            return false;
        }
    }
}
