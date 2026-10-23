package it.ddone.simplenotes.task;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
import static org.junit.jupiter.api.Assertions.*;

class TaskDueTest {
    private final ObjectMapper mapper = new ObjectMapper();

    private TaskDue parse(String body) throws Exception {
        return TaskDue.parse(mapper.readTree(body));
    }

    @Test
    void dateOnlyNeverBecomesAnInstant() throws Exception {
        TaskDue due = parse("""
            {"kind":"date","date":"2026-10-26"}""");
        assertEquals("date", due.kind());
        assertEquals("2026-10-26", due.toPayload().get("date"));
        assertNull(due.instant());
        assertNull(due.timeZone());
    }

    @Test
    void explicitMidnightIsTimedNotDateOnly() throws Exception {
        TaskDue due = parse("""
            {"kind":"datetime","date":"2026-10-26","time":"00:00",
             "timeZone":"Europe/Rome","offsetSeconds":3600,
             "instant":"2026-10-25T23:00:00Z"}""");
        assertEquals("datetime", due.kind());
        assertEquals("00:00", due.toPayload().get("time"));
    }

    @Test
    void overlappingRomeClockRequiresChosenCorrectOffset() throws Exception {
        TaskDue summer = parse("""
            {"kind":"datetime","date":"2026-10-25","time":"02:30",
             "timeZone":"Europe/Rome","offsetSeconds":7200,
             "instant":"2026-10-25T00:30:00Z"}""");
        TaskDue winter = parse("""
            {"kind":"datetime","date":"2026-10-25","time":"02:30",
             "timeZone":"Europe/Rome","offsetSeconds":3600,
             "instant":"2026-10-25T01:30:00Z"}""");
        assertNotEquals(summer.instant(), winter.instant());
        assertEquals(7200, summer.offsetSeconds());
        assertEquals(3600, winter.offsetSeconds());
    }

    @Test
    void gapAndMismatchedInstantAreRejected() {
        assertThrows(ResponseStatusException.class, () -> parse("""
            {"kind":"datetime","date":"2026-03-29","time":"02:30",
             "timeZone":"Europe/Rome","offsetSeconds":3600,
             "instant":"2026-03-29T01:30:00Z"}"""));
        assertThrows(ResponseStatusException.class, () -> parse("""
            {"kind":"datetime","date":"2026-10-25","time":"02:30",
             "timeZone":"Europe/Rome","offsetSeconds":7200,
             "instant":"2026-10-25T01:30:00Z"}"""));
        assertThrows(ResponseStatusException.class, () -> parse("""
            {"kind":"datetime","date":"2026-10-26","time":"15:30",
             "timeZone":"Bad/Zone","offsetSeconds":3600,
             "instant":"2026-10-26T14:30:00Z"}"""));
    }

    @Test
    void legacyDoesNotGuessWhatMidnightMeant() throws Exception {
        TaskDue old = parse("""
            {"kind":"legacy","instant":"2026-10-24T22:00:00Z"}""");
        assertEquals("legacy", old.kind());
        assertNull(old.date());
        assertEquals("2026-10-24T22:00:00Z", old.toPayload().get("instant"));
        assertThrows(ResponseStatusException.class,
            () -> parse("{\"kind\":\"date\",\"date\":\"2026-10-26\",\"time\":\"00:00\"}"));
    }
}
