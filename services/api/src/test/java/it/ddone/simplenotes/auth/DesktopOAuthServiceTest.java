package it.ddone.simplenotes.auth;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class DesktopOAuthServiceTest {
    @Test void acceptsLoopbackRedirectOnly() {
        assertTrue(DesktopOAuthService.validRedirect("http://127.0.0.1:49427/oauth/callback"));
        assertFalse(DesktopOAuthService.validRedirect("http://localhost:49427/oauth/callback"));
        assertFalse(DesktopOAuthService.validRedirect("https://evil.example/oauth/callback"));
        assertFalse(DesktopOAuthService.validRedirect("http://127.0.0.1:49427/other"));
        assertFalse(DesktopOAuthService.validRedirect("http://127.0.0.1:49427/oauth/callback?x=y"));
        assertFalse(DesktopOAuthService.validRedirect("http://evil.example@127.0.0.1:49427/oauth/callback"));
    }
}
