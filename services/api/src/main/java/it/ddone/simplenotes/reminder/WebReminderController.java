
package it.ddone.simplenotes.reminder;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/v1/reminders/rules")
public class WebReminderController {
 public record Rule(@NotBlank @Pattern(regexp="[a-zA-Z0-9_-]{3,90}") String id,@NotBlank String kind,@NotNull Integer leadMinutes,@NotNull @Min(0) @Max(3) Integer minPriority,@NotNull Boolean enabled) {}
 public record Config(boolean enabled,long version,List<Rule> rules) {}
 public record Replace(@NotNull Boolean enabled,@NotNull @Min(0) Long expectedVersion,@NotNull @Size(max=20) List<@NotNull @Valid Rule> rules) {}
 public record Occurrence(UUID id,UUID taskId,String title,String kind,Instant dueAt,Instant fireAt,int leadMinutes) {}
 private final JdbcTemplate jdbc;
 private final ObjectMapper json;
 public WebReminderController(JdbcTemplate jdbc,ObjectMapper json){this.jdbc=jdbc;this.json=json;}
 private UUID owner(Jwt jwt){return UUID.fromString(jwt.getSubject());}
 private List<Rule> decode(String raw){try{return json.readValue(raw,new TypeReference<List<Rule>>(){});}catch(Exception e){throw new IllegalStateException("Invalid stored reminder rules",e);}}
 private Config read(UUID owner){var rows=jdbc.query("SELECT enabled,version,rules_json FROM web_reminder_config WHERE owner_id=?",(rs,i)->new Config(rs.getBoolean(1),rs.getLong(2),decode(rs.getString(3))),owner);return rows.isEmpty()?new Config(false,0,List.of()):rows.get(0);}
 @GetMapping("/preferences") public Config preferences(@AuthenticationPrincipal Jwt jwt){return read(owner(jwt));}
 @PutMapping("/preferences") @Transactional
 public Config replace(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Replace req){
  Set<String> ids=new HashSet<>();for(Rule r:req.rules())if(!ids.add(r.id())||!Set.of("due","block").contains(r.kind())||!ServerReminderService.ALLOWED_LEADS.contains(r.leadMinutes()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid reminder rule");
  UUID owner=owner(jwt);jdbc.query("SELECT pg_advisory_xact_lock(hashtext(?))",rs->{},owner.toString());Config old=read(owner);
  if(old.version()!=req.expectedVersion()||old.version()==Long.MAX_VALUE)throw new ResponseStatusException(HttpStatus.CONFLICT,"Reminder rules changed");
  String raw;try{raw=json.writeValueAsString(req.rules());}catch(Exception e){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid rules");}
  if(old.version()==0)jdbc.update("INSERT INTO web_reminder_config(owner_id,enabled,version,rules_json) VALUES(?,?,1,?)",owner,req.enabled(),raw);
  else jdbc.update("UPDATE web_reminder_config SET enabled=?,version=version+1,rules_json=?,updated_at=now() WHERE owner_id=?",req.enabled(),raw,owner);
  if(old.enabled()!=req.enabled())jdbc.update("UPDATE server_reminder_occurrence SET acknowledged_at=now() WHERE owner_id=? AND acknowledged_at IS NULL",owner);
  return new Config(req.enabled(),old.version()+1,List.copyOf(req.rules()));
 }
 // The validated config is the only source of rule values. No arbitrary SQL.
 private static final String CANDIDATES="""
 WITH active_rules AS (
   SELECT c.owner_id,c.version,r FROM web_reminder_config c
   CROSS JOIN LATERAL jsonb_array_elements(c.rules_json::jsonb) r
   WHERE c.enabled AND (r->>'enabled')::boolean
 ), slots AS (
   SELECT t.id AS task_id,t.owner_id,a.version,a.r->>'id' AS rule_id,'due' AS kind,'' AS slot_id,t.due_at AS scheduled_at,(a.r->>'leadMinutes')::int AS lead_minutes
   FROM active_rules a JOIN task t ON t.owner_id=a.owner_id
   WHERE a.r->>'kind'='due' AND t.due_kind='datetime' AND t.due_at IS NOT NULL
     AND t.deleted_at IS NULL AND t.completed_at IS NULL AND t.priority >= (a.r->>'minPriority')::int
   UNION ALL
   SELECT t.id,t.owner_id,a.version,a.r->>'id','block',b->>'id',(b->>'start')::timestamptz,(a.r->>'leadMinutes')::int
   FROM active_rules a JOIN task t ON t.owner_id=a.owner_id
   CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN t.blocks_json::jsonb='[]'::jsonb AND t.block_start_at IS NOT NULL
       THEN jsonb_build_array(jsonb_build_object('id','legacy','start',t.block_start_at))
       ELSE t.blocks_json::jsonb END) b
   WHERE a.r->>'kind'='block' AND t.deleted_at IS NULL AND t.completed_at IS NULL AND t.priority >= (a.r->>'minPriority')::int
 ), candidates AS (
   SELECT *,scheduled_at-lead_minutes*INTERVAL '1 minute' AS fire_at FROM slots
   WHERE scheduled_at-lead_minutes*INTERVAL '1 minute' BETWEEN now()-INTERVAL '24 hours' AND now()
 )
 """;
 @Scheduled(initialDelayString="${app.reminders.scan-initial-ms:60000}",fixedDelayString="${app.reminders.scan-interval-ms:60000}") @Transactional
 public int scan(){return jdbc.update(CANDIDATES+"""
   INSERT INTO web_reminder_occurrence(id,owner_id,task_id,config_version,rule_id,kind,slot_id,scheduled_at,fire_at,lead_minutes)
   SELECT gen_random_uuid(),c.owner_id,c.task_id,c.version,c.rule_id,c.kind,c.slot_id,c.scheduled_at,c.fire_at,c.lead_minutes
   FROM candidates c WHERE NOT EXISTS(SELECT 1 FROM web_reminder_occurrence o WHERE o.owner_id=c.owner_id AND o.task_id=c.task_id AND o.config_version=c.version AND o.rule_id=c.rule_id AND o.slot_id=c.slot_id AND o.scheduled_at=c.scheduled_at)
   ORDER BY c.fire_at,c.task_id LIMIT 200 ON CONFLICT DO NOTHING
   """);}
 @GetMapping("/occurrences") @Transactional(readOnly=true)
 public List<Occurrence> unread(@AuthenticationPrincipal Jwt jwt){return jdbc.query(CANDIDATES+"""
   SELECT o.id,o.task_id,t.title,o.kind,o.scheduled_at,o.fire_at,o.lead_minutes
   FROM web_reminder_occurrence o JOIN candidates c ON c.owner_id=o.owner_id AND c.task_id=o.task_id AND c.version=o.config_version AND c.rule_id=o.rule_id AND c.slot_id=o.slot_id AND c.scheduled_at=o.scheduled_at
   JOIN task t ON t.id=o.task_id AND t.owner_id=o.owner_id
   WHERE o.owner_id=? AND o.acknowledged_at IS NULL ORDER BY o.fire_at DESC,o.id LIMIT 50
   """,(rs,i)->new Occurrence(rs.getObject(1,UUID.class),rs.getObject(2,UUID.class),rs.getString(3),rs.getString(4),rs.getTimestamp(5).toInstant(),rs.getTimestamp(6).toInstant(),rs.getInt(7)),owner(jwt));}
 @PostMapping("/occurrences/{id}/ack") @ResponseStatus(HttpStatus.NO_CONTENT)
 public void ack(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){if(jdbc.update("UPDATE web_reminder_occurrence SET acknowledged_at=COALESCE(acknowledged_at,now()) WHERE owner_id=? AND id=?",owner(jwt),id)!=1)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Reminder not found");}
 @Scheduled(initialDelayString="${app.reminders.prune-initial-ms:3600000}",fixedDelayString="${app.reminders.prune-interval-ms:86400000}") @Transactional
 public int prune(){return jdbc.update("DELETE FROM web_reminder_occurrence WHERE fire_at<now()-INTERVAL '30 days'");}
}
