package it.ddone.simplenotes.auth;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final AuthService auth;
    private final DesktopOAuthService desktop;
    public AuthController(AuthService auth, DesktopOAuthService desktop) {
        this.auth = auth;
        this.desktop = desktop;
    }

    public record GoogleLoginRequest(@NotBlank String idToken) {}
    public record RefreshRequest(@NotBlank String refreshToken) {}
    public record DesktopCodeRequest(@NotBlank String code, @NotBlank String codeVerifier,
        @NotBlank String redirectUri) {}

    @PostMapping("/google")
    public AuthService.AuthResponse googleLogin(@Valid @RequestBody GoogleLoginRequest body) {
        return auth.signIn(body.idToken());
    }

    @PostMapping("/desktop/exchange")
    public AuthService.AuthResponse desktopLogin(@Valid @RequestBody DesktopCodeRequest body) {
        return desktop.exchange(body.code(), body.codeVerifier(), body.redirectUri());
    }

    @PostMapping("/refresh")
    public AuthService.AuthResponse refresh(@Valid @RequestBody RefreshRequest body) {
        return auth.refresh(body.refreshToken());
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@Valid @RequestBody RefreshRequest body) {
        auth.logout(body.refreshToken());
        return ResponseEntity.noContent().build();
    }
}
