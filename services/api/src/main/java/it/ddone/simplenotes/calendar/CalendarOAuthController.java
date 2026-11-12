package it.ddone.simplenotes.calendar;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/** Calendar grants are distinct from login and never share provider tokens. */
@RestController
@RequestMapping("/api/v1/calendars")
public class CalendarOAuthController {
    private final CalendarOAuthService oauth;
    private final CalendarEventsService events;

    public CalendarOAuthController(CalendarOAuthService oauth, CalendarEventsService events) {
        this.oauth = oauth; this.events = events;
    }

    private static UUID owner(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }

    @GetMapping
    public List<CalendarOAuthService.ProviderStatus> status(@AuthenticationPrincipal Jwt jwt) {
        return oauth.status(owner(jwt));
    }

    @PostMapping("/{provider}/authorize")
    public CalendarOAuthService.Authorization authorize(@AuthenticationPrincipal Jwt jwt,
            @PathVariable String provider) {
        return oauth.begin(owner(jwt), provider);
    }

    @GetMapping(value = "/oauth/{provider}/callback", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> callback(@PathVariable String provider,
            @RequestParam(required = false) String state,
            @RequestParam(required = false) String code,
            @RequestParam(required = false) String error) {
        oauth.complete(provider, state, code, error);
        return ResponseEntity.ok()
            .cacheControl(CacheControl.noStore())
            .header("Referrer-Policy", "no-referrer")
            .header("X-Content-Type-Options", "nosniff")
            .body("Calendario collegato. Puoi tornare a Simple Notes e aggiornare gli eventi.");
    }

    @DeleteMapping("/{provider}")
    public ResponseEntity<Void> disconnect(@AuthenticationPrincipal Jwt jwt,
            @PathVariable String provider) {
        oauth.disconnect(owner(jwt), provider);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{provider}/events")
    public CalendarEventsService.Events events(@AuthenticationPrincipal Jwt jwt,
            @PathVariable String provider, @RequestParam Instant start,
            @RequestParam Instant end) {
        return events.read(owner(jwt), provider, start, end);
    }
}
