
package it.ddone.simplenotes.calendar;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class CalendarLinkProjectionTest {
 @Test void preservesCivilDateAndTimedInstant() throws Exception {
  var mapper=new ObjectMapper();
  var payload=mapper.readTree("{\"title\":\"Task\",\"due\":{\"kind\":\"date\",\"date\":\"2026-12-01\"}}");
  var body=CalendarLinkController.googleBody(mapper,payload,null);
  assertEquals("2026-12-01",body.path("start").path("date").asText());assertEquals("2026-12-02",body.path("end").path("date").asText());
  var event=new CalendarEventsService.Event("x","Task","Google",null,null,Instant.parse("2026-12-01T08:30:00Z"),Instant.parse("2026-12-01T09:00:00Z"));
  assertEquals("datetime",CalendarLinkController.importedDue(event).kind());assertEquals(event.startUtc(),CalendarLinkController.importedDue(event).instant());
 }
}
