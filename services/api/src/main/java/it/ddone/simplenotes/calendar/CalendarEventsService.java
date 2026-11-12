package it.ddone.simplenotes.calendar;

import com.fasterxml.jackson.databind.JsonNode;
import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/** On-demand provider reads only. Never writes to Simple Notes tasks/outbox. */
@Service
public class CalendarEventsService {
    public record Event(String id, String title, String source, String startDay,
        String endDay, Instant startUtc, Instant endUtc) {}
    public record Events(String provider, Instant start, Instant end,
        List<Event> events, boolean truncated) {}

    private final CalendarOAuthService oauth;
    private final CalendarHttpGateway http;

    public CalendarEventsService(CalendarOAuthService oauth, CalendarHttpGateway http) {
        this.oauth = oauth; this.http = http;
    }

    public Events read(UUID owner, String provider, Instant start, Instant end) {
        if (start == null || end == null || !end.isAfter(start)
                || Duration.between(start, end).compareTo(Duration.ofDays(31)) > 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Calendar view must span 1 second to 31 days");
        }
        String bearer = oauth.bearer(owner, provider);
        boolean microsoft = "microsoft".equals(provider);
        URI endpoint;
        if (microsoft) {
            Map<String,String> params = new LinkedHashMap<>();
            params.put("startDateTime", start.toString());
            params.put("endDateTime", end.toString());
            params.put("$top", "100");
            params.put("$select", "id,subject,start,end,isAllDay,isCancelled");
            endpoint = CalendarOAuthService.uri(
                "https://graph.microsoft.com/v1.0/me/calendarView", params);
        } else {
            Map<String,String> params = new LinkedHashMap<>();
            params.put("timeMin", start.toString());
            params.put("timeMax", end.toString());
            params.put("singleEvents", "true");
            params.put("maxResults", "100");
            params.put("fields", "items(id,summary,status,start,end),nextPageToken");
            endpoint = CalendarOAuthService.uri(
                "https://www.googleapis.com/calendar/v3/calendars/primary/events", params);
        }
        JsonNode root = http.read(endpoint, bearer, microsoft);
        JsonNode items = microsoft ? root.path("value") : root.path("items");
        if (!items.isArray()) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                "Invalid calendar event list");
        }
        List<Event> events = new ArrayList<>();
        for (JsonNode item : items) {
            if (events.size() == 100) break;
            if (microsoft ? item.path("isCancelled").asBoolean(false)
                : "cancelled".equals(item.path("status").asText(""))) continue;
            Event value = parse(provider, item);
            if (value != null) events.add(value);
        }
        boolean truncated = microsoft
            ? root.hasNonNull("@odata.nextLink") : root.hasNonNull("nextPageToken");
        return new Events(provider, start, end, List.copyOf(events), truncated);
    }

    static Event parse(String provider, JsonNode item) {
        String id = item.path("id").asText("");
        if (id.isBlank() || id.length() > 512) return null;
        String title = "microsoft".equals(provider)
            ? item.path("subject").asText("") : item.path("summary").asText("");
        if (title.isBlank()) title = "Senza titolo";
        if (title.length() > 255) title = title.substring(0, 255);
        JsonNode begin = item.path("start"), finish = item.path("end");
        if (!begin.isObject() || !finish.isObject()) return null;
        boolean allDay = "microsoft".equals(provider)
            ? item.path("isAllDay").asBoolean(false) : begin.hasNonNull("date");
        String source = "microsoft".equals(provider) ? "Outlook" : "Google Calendar";
        try {
            if (allDay) {
                String startDay = "microsoft".equals(provider)
                    ? begin.path("dateTime").asText("").substring(0, 10)
                    : begin.path("date").asText("");
                String endDay = "microsoft".equals(provider)
                    ? finish.path("dateTime").asText("").substring(0, 10)
                    : finish.path("date").asText("");
                if (!LocalDate.parse(endDay).isAfter(LocalDate.parse(startDay))) return null;
                return new Event(id, title, source, startDay, endDay, null, null);
            }
            Instant a = "microsoft".equals(provider)
                ? graphInstant(begin.path("dateTime").asText(""))
                : OffsetDateTime.parse(begin.path("dateTime").asText("")).toInstant();
            Instant b = "microsoft".equals(provider)
                ? graphInstant(finish.path("dateTime").asText(""))
                : OffsetDateTime.parse(finish.path("dateTime").asText("")).toInstant();
            if (!b.isAfter(a)) return null;
            return new Event(id, title, source, null, null, a, b);
        } catch (java.time.DateTimeException | IndexOutOfBoundsException ex) {
            return null;
        }
    }

    private static Instant graphInstant(String text) {
        try { return OffsetDateTime.parse(text).toInstant(); }
        catch (DateTimeParseException ex) {
            // Every Graph request explicitly asks for UTC in the Prefer header.
            return LocalDateTime.parse(text).toInstant(ZoneOffset.UTC);
        }
    }
}
