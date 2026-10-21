package it.ddone.simplenotes.auth;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final AuthService auth;
    public AuthController(AuthService auth) { this.auth = auth; }

    public record GoogleLoginRequest(@NotBlank String idToken) {}
    public record RefreshRequest(@NotBlank String refreshToken) {}

    @PostMapping("/google")
    public ResponseEntity<AuthService.AuthResponse> googleLogin(@Valid @RequestBody GoogleLoginRequest body) {
        return ResponseEntity.ok(auth.signIn(body.idToken()));
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
