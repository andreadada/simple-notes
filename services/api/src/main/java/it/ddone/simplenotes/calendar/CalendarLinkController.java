
package it.ddone.simplenotes.calendar;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import it.ddone.simplenotes.sync.SyncController;
import it.ddone.simplenotes.sync.SyncService;
import it.ddone.simplenotes.task.TaskDue;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Manual two-way projection: title and deadline/start only; never deletes events,
 * modifies attendees, or rewrites unrelated task fields. Explicit Google write
 * consent; Outlook read/import remains available without expanded grants. */
@RestController
@RequestMapping("/api/v1/calendar-links")
public class CalendarLinkController {
    public record Link(UUID taskId,String provider,String eventId) {}
    public record ImportEvent(@NotBlank String provider,@NotBlank @Size(max=512) String eventId) {}
    public record Publish(@NotNull UUID taskId,@NotNull @Min(0) Long expectedVersion) {}
    public record Direction(@NotNull @Min(0) Long expectedVersion,@NotBlank @Size(max=128) String externalRevision) {}
    public record Preview(Link link,long taskVersion,String taskTitle,JsonNode taskDue,CalendarEventsService.Event event,String externalRevision,boolean canPush) {}
    public record Status(boolean googleWriteEnabled) {}
    private record External(CalendarEventsService.Event event,JsonNode raw,String revision) {}
    private final JdbcTemplate jdbc;
    private final SyncService sync;
    private final CalendarOAuthService oauth;
    private final CalendarOAuthConfig config;
    private final CalendarHttpGateway http;
    private final ObjectMapper json;
    public CalendarLinkController(JdbcTemplate jdbc,SyncService sync,CalendarOAuthService oauth,CalendarOAuthConfig config,CalendarHttpGateway http,ObjectMapper json){this.jdbc=jdbc;this.sync=sync;this.oauth=oauth;this.config=config;this.http=http;this.json=json;}
    private UUID owner(Jwt jwt){return UUID.fromString(jwt.getSubject());}
    private static ResponseStatusException err(HttpStatus s,String msg){return new ResponseStatusException(s,msg);}
    private static String provider(String p){if(!Set.of("google","microsoft").contains(p))throw err(HttpStatus.BAD_REQUEST,"Unknown provider");return p;}
    private static URI endpoint(String provider,String id){
        String base=provider(provider).equals("google")?"https://www.googleapis.com/calendar/v3/calendars/primary/events":"https://graph.microsoft.com/v1.0/me/events";
        if(id==null)return URI.create(base);
        if(id.isBlank()||id.length()>512||id.indexOf(0)>=0||id.equals(".")||id.equals(".."))throw err(HttpStatus.BAD_REQUEST,"Invalid event ID");
        return URI.create(base+"/"+URLEncoder.encode(id,StandardCharsets.UTF_8).replace("+","%20"));
    }
    private static String revision(CalendarEventsService.Event event,JsonNode raw){
        try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest((event.toString()+"\n"+raw.path("etag").asText("")+"\n"+raw.path("@odata.etag").asText("")+"\n"+raw.path("changeKey").asText("")).getBytes(StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException(e);}
    }
    private External remote(UUID owner,String provider,String id){
        JsonNode raw=http.event(endpoint(provider,id),oauth.bearer(owner,provider),"microsoft".equals(provider),"GET",null,null);
        var e=CalendarEventsService.parse(provider,raw);
        if(e==null||!id.equals(e.id())||raw.path("isCancelled").asBoolean()||"cancelled".equals(raw.path("status").asText()))throw err(HttpStatus.CONFLICT,"Event unavailable");
        return new External(e,raw,revision(e,raw));
    }
    private boolean writable(External e){
        JsonNode x=e.raw();
        return config.googleWriteEnabled()&&x.path("organizer").path("self").asBoolean(false)&&!x.hasNonNull("recurringEventId")&&!x.hasNonNull("recurrence")&&x.path("attendees").size()==0&&!"true".equals(x.path("locked").asText())&&!x.path("etag").asText("").isBlank()&&"default".equals(x.path("eventType").asText("default"));
    }
    private List<Link> links(UUID owner){return jdbc.query("SELECT task_id,provider,event_id FROM calendar_task_link WHERE owner_id=? ORDER BY created_at",(rs,n)->new Link(rs.getObject(1,UUID.class),rs.getString(2),rs.getString(3)),owner);}
    private Link link(UUID owner,UUID task,String p){return links(owner).stream().filter(x->x.taskId().equals(task)&&x.provider().equals(p)).findFirst().orElseThrow(()->err(HttpStatus.NOT_FOUND,"Link unavailable"));}
    private SyncController.LatestChange task(UUID owner,UUID task){var x=sync.latest(owner,"task",task);if(x.deleted())throw err(HttpStatus.NOT_FOUND,"Task unavailable");return x;}
    private void expected(SyncController.LatestChange t,long version){if(t.version()!=version)throw err(HttpStatus.CONFLICT,"Task revision changed");}
    private void insert(UUID owner,Link link){jdbc.update("INSERT INTO calendar_task_link(owner_id,task_id,provider,event_id) VALUES(?,?,?,?)",owner,link.taskId(),link.provider(),link.eventId());}
    static TaskDue importedDue(CalendarEventsService.Event event){
        if(event.startDay()!=null)return new TaskDue("date",LocalDate.parse(event.startDay()),null,null,null,null);
        Instant instant=event.startUtc();var z=instant.atZone(ZoneOffset.UTC);
        if(z.getSecond()!=0||z.getNano()!=0)return TaskDue.fromOldInstant(instant);
        return new TaskDue("datetime",z.toLocalDate(),z.toLocalTime(),"Etc/UTC",instant,0);
    }
    private ObjectNode incoming(ObjectNode payload,External external){
        TaskDue due=importedDue(external.event());payload.put("title",external.event().title());payload.set("due",json.valueToTree(due.toPayload()));payload.put("dueAt",due.instant()==null?"":due.instant().toString());return payload;
    }
    static ObjectNode googleBody(ObjectMapper json,JsonNode payload,CalendarEventsService.Event existing){
        TaskDue due=TaskDue.parse(payload.path("due"));
        if("none".equals(due.kind()))throw err(HttpStatus.BAD_REQUEST,"Task has no deadline");
        ObjectNode body=json.createObjectNode().put("summary",payload.path("title").asText());
        if("date".equals(due.kind())){
            long days=existing!=null&&existing.startDay()!=null?java.time.temporal.ChronoUnit.DAYS.between(LocalDate.parse(existing.startDay()),LocalDate.parse(existing.endDay())):1;
            body.putObject("start").put("date",due.date().toString());body.putObject("end").put("date",due.date().plusDays(Math.max(1,days)).toString());
        }else{
            Duration duration=existing!=null&&existing.startUtc()!=null?Duration.between(existing.startUtc(),existing.endUtc()):Duration.ofMinutes(30);
            body.putObject("start").put("dateTime",due.instant().toString());body.putObject("end").put("dateTime",due.instant().plus(duration).toString());
        }
        return body;
    }
    private Preview preview(Link link,SyncController.LatestChange t,External x){return new Preview(link,t.version(),t.payload().path("title").asText(),t.payload().path("due"),x.event(),x.revision(),"google".equals(link.provider())&&writable(x));}
    @GetMapping("/status") public Status status(){return new Status(config.googleWriteEnabled());}
    @GetMapping public List<Link> list(@AuthenticationPrincipal Jwt jwt){return links(owner(jwt));}
    @PostMapping("/import") @Transactional
    public Link importEvent(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody ImportEvent req){
        UUID owner=owner(jwt);String p=provider(req.provider());External x=remote(owner,p,req.eventId());
        sync.lockAccount(owner);var existing=links(owner).stream().filter(l->l.provider().equals(p)&&l.eventId().equals(req.eventId())).findFirst();
        if(existing.isPresent())return existing.get();
        UUID id=UUID.randomUUID();ObjectNode payload=incoming(json.createObjectNode().put("description","").put("completed",false),x);
        sync.applyCollaborator(owner,new SyncController.ApplyRequest(UUID.randomUUID(),id,"task","upsert",null,payload,null));
        Link link=new Link(id,p,req.eventId());insert(owner,link);return link;
    }
    @PostMapping("/google/publish") @Transactional
    public Link publish(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Publish req){
        if(!config.googleWriteEnabled())throw err(HttpStatus.FORBIDDEN,"Google write not enabled");
        UUID owner=owner(jwt);sync.lockAccount(owner);var t=task(owner,req.taskId());expected(t,req.expectedVersion());
        var existing=links(owner).stream().filter(l->l.taskId().equals(req.taskId())&&l.provider().equals("google")).findFirst();if(existing.isPresent())return existing.get();
        String id="sn"+UUID.nameUUIDFromBytes((owner+":"+req.taskId()).getBytes(StandardCharsets.UTF_8)).toString().replace("-","");
        ObjectNode body=googleBody(json,t.payload(),null);body.put("id",id);body.putObject("extendedProperties").putObject("private").put("simpleNotesTask",req.taskId().toString());
        JsonNode result;
        try{result=http.event(endpoint("google",null),oauth.bearer(owner,"google"),false,"POST",body,null);}
        catch(ResponseStatusException e){if(e.getStatusCode()!=HttpStatus.CONFLICT)throw e;result=remote(owner,"google",id).raw();}
        if(!id.equals(result.path("id").asText())||!req.taskId().toString().equals(result.path("extendedProperties").path("private").path("simpleNotesTask").asText()))throw err(HttpStatus.CONFLICT,"Event ID already in use");
        Link link=new Link(req.taskId(),"google",id);insert(owner,link);return link;
    }
    @GetMapping("/{taskId}/{provider}")
    public Preview inspect(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID taskId,@PathVariable String provider){
        UUID owner=owner(jwt);Link l=link(owner,taskId,provider(provider));return preview(l,task(owner,taskId),remote(owner,l.provider(),l.eventId()));
    }
    @PostMapping("/{taskId}/{provider}/pull") @Transactional
    public Preview pull(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID taskId,@PathVariable String provider,@Valid @RequestBody Direction request){
        UUID owner=owner(jwt);Link l=link(owner,taskId,provider(provider));External x=remote(owner,l.provider(),l.eventId());
        if(!x.revision().equals(request.externalRevision()))throw err(HttpStatus.CONFLICT,"Calendar revision changed");
        sync.lockAccount(owner);var t=task(owner,taskId);expected(t,request.expectedVersion());
        ObjectNode payload=incoming((ObjectNode)t.payload().deepCopy(),x);
        sync.applyCollaborator(owner,new SyncController.ApplyRequest(UUID.randomUUID(),taskId,"task","upsert",t.version(),payload,null));
        return preview(l,task(owner,taskId),x);
    }
    @PostMapping("/{taskId}/google/push") @Transactional
    public Preview push(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID taskId,@Valid @RequestBody Direction request){
        UUID owner=owner(jwt);sync.lockAccount(owner);Link l=link(owner,taskId,"google");var t=task(owner,taskId);expected(t,request.expectedVersion());
        External x=remote(owner,"google",l.eventId());if(!x.revision().equals(request.externalRevision()))throw err(HttpStatus.CONFLICT,"Calendar revision changed");
        if(!writable(x))throw err(HttpStatus.FORBIDDEN,"Event is not an editable personal Google event");
        URI url=URI.create(endpoint("google",l.eventId()).toString()+"?sendUpdates=none");
        http.event(url,oauth.bearer(owner,"google"),false,"PATCH",googleBody(json,t.payload(),x.event()),x.raw().path("etag").asText());
        return preview(l,t,remote(owner,"google",l.eventId()));
    }
}
