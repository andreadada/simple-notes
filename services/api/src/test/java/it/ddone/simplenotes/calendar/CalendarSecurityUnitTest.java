package it.ddone.simplenotes.calendar;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class CalendarSecurityUnitTest {
    private static CalendarOAuthConfig configured() {
        return new CalendarOAuthConfig("https://api.example.test",
            "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
            "google-id", "google-secret", "ms-id", "ms-secret");
    }

    @Test
    void disabledWithoutCredentialsAndRejectsUnsafeRedirects() {
        CalendarOAuthConfig disabled = new CalendarOAuthConfig(
            "", "", "", "", "", "");
        assertFalse(disabled.available("google"));
        assertFalse(disabled.available("microsoft"));
        assertThrows(IllegalStateException.class,
            () -> new CalendarOAuthConfig("https://evil.test/redirect",
                "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
                "google-id", "google-secret", "", ""));
        assertEquals("https://api.example.test/api/v1/calendars/oauth/google/callback",
            configured().callback("google"));
    }

    @Test
    void vaultIntegrityBoundToOwnerProviderAndPurpose() {
        CalendarTokenVault vault = new CalendarTokenVault(configured());
        UUID alice = UUID.randomUUID(), bob = UUID.randomUUID();
        String sealed = vault.seal("provider-refresh-secret",alice,"google","refresh");
        assertNotEquals("provider-refresh-secret",sealed);
        assertEquals("provider-refresh-secret",
            vault.open(sealed,alice,"google","refresh"));
        assertThrows(IllegalStateException.class,
            () -> vault.open(sealed,bob,"google","refresh"));
        assertThrows(IllegalStateException.class,
            () -> vault.open(sealed,alice,"microsoft","refresh"));
        assertThrows(IllegalStateException.class,
            () -> vault.open(sealed,alice,"google","access"));
    }

    @Test
    void providerEventsKeepDateOnlyAndTimedTimesDistinct() throws Exception {
        ObjectMapper json = new ObjectMapper();
        var googleDay = CalendarEventsService.parse("google",
            json.readTree("""
                {"id":"a","summary":"Holiday","start":{"date":"2026-11-12"},
                 "end":{"date":"2026-11-14"}}"""));
        assertNotNull(googleDay);
        assertEquals("2026-11-12",googleDay.startDay());
        assertNull(googleDay.startUtc());
        var microsoft = CalendarEventsService.parse("microsoft",
            json.readTree("""
                {"id":"b","subject":"Meeting","isAllDay":false,
                "start":{"dateTime":"2026-11-12T13:30:00.0000000","timeZone":"UTC"},
                "end":{"dateTime":"2026-11-12T14:00:00.0000000","timeZone":"UTC"}}"""));
        assertNotNull(microsoft);
        assertEquals(Instant.parse("2026-11-12T13:30:00Z"),microsoft.startUtc());
        assertNull(CalendarEventsService.parse("google",json.readTree("""
            {"id":"bad","start":{"dateTime":"bad"},"end":{"dateTime":"bad"}}""")));
    }

    @Test
    void pkceChallengeIsDeterministicWithoutExposingVerifier() {
        String verifier = CalendarOAuthService.randomToken();
        String challenge = CalendarOAuthService.challenge(verifier);
        assertEquals(43, verifier.length());
        assertEquals(43, challenge.length());
        assertNotEquals(verifier, challenge);
        assertEquals(challenge,CalendarOAuthService.challenge(verifier));
        assertEquals(64,CalendarOAuthService.digest(verifier).length());
    }
}
