package it.ddone.simplenotes.web;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Private generic tables. A whole-table CAS protects schema, rows and views;
 * no arbitrary SQL, no client-provided owner, no financial-specific assumptions. */
@RestController
@RequestMapping("/api/v1/workspace/tables")
public class WorkspaceTableController {
    private final JdbcTemplate jdbc;
    private final ObjectMapper json;
    public WorkspaceTableController(JdbcTemplate jdbc,ObjectMapper json){this.jdbc=jdbc;this.json=json;}
    public record Summary(UUID id,long version,String name,boolean archived){}
    public record Table(UUID id,long version,JsonNode data,boolean archived){}
    public record Write(@NotNull @Min(0) Long expectedVersion,@NotNull JsonNode data){}
    public record Archive(@NotNull @Min(1) Long expectedVersion,boolean archived){}
    private UUID owner(Jwt jwt){return UUID.fromString(jwt.getSubject());}
    private static ResponseStatusException bad(){return new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid workspace table");}
    private static ResponseStatusException conflict(){return new ResponseStatusException(HttpStatus.CONFLICT,"Workspace table revision changed");}
    private JsonNode parse(String v){try{return json.readTree(v);}catch(Exception ex){throw new IllegalStateException(ex);}}
    private static boolean text(JsonNode n,int max){return n.isTextual()&&n.textValue().length()<=max;}
    private static String id(JsonNode n){if(!text(n,36))throw bad();try{return UUID.fromString(n.asText()).toString();}catch(Exception ex){throw bad();}}
    private static void keys(JsonNode n,Set<String> allowed){if(!n.isObject())throw bad();n.fieldNames().forEachRemaining(k->{if(!allowed.contains(k))throw bad();});}
    static String validate(JsonNode d){
        keys(d,Set.of("name","fields","rows","views","activeView"));
        if(!text(d.path("name"),100)||d.path("name").asText().isBlank())throw bad();
        JsonNode fs=d.path("fields"),rows=d.path("rows"),views=d.path("views");
        if(!fs.isArray()||fs.isEmpty()||fs.size()>40||!rows.isArray()||rows.size()>500||!views.isArray()||views.isEmpty()||views.size()>20)throw bad();
        Map<String,JsonNode> fields=new HashMap<>();
        for(JsonNode f:fs){
            keys(f,Set.of("id","name","type","options"));
            if(!text(f.path("name"),80)||f.path("name").asText().isBlank()||!Set.of("text","number","checkbox","date","select","url").contains(f.path("type").asText())||fields.put(id(f.path("id")),f)!=null)throw bad();
            JsonNode opts=f.path("options");if(!opts.isArray()||opts.size()>30)throw bad();
            for(JsonNode o:opts)if(!text(o,80)||o.asText().isBlank())throw bad();
        }
        Set<String> rowIds=new HashSet<>();
        for(JsonNode row:rows){
            keys(row,Set.of("id","values"));if(!rowIds.add(id(row.path("id")))||!row.path("values").isObject())throw bad();
            row.path("values").fields().forEachRemaining(e->{JsonNode f=fields.get(e.getKey()),v=e.getValue();if(f==null)throw bad();if(v.isNull())return;String type=f.path("type").asText();boolean ok=switch(type){
                case "checkbox" -> v.isBoolean();
                case "number" -> v.isNumber()&&Double.isFinite(v.asDouble());
                case "date" -> {try{yield text(v,10)&&java.time.LocalDate.parse(v.asText()).toString().equals(v.asText());}catch(Exception ex){yield false;}}
                case "select" -> {boolean found=false;for(JsonNode o:f.path("options"))if(o.equals(v))found=true;yield found;}
                default -> text(v,4096);
            };if(!ok)throw bad();});
        }
        Set<String> viewIds=new HashSet<>();
        for(JsonNode v:views){
            keys(v,Set.of("id","name","kind","columns","sort","direction","group","filters","logic","density","cardSize"));
            if(!viewIds.add(id(v.path("id")))||!text(v.path("name"),60)||v.path("name").asText().isBlank()||!Set.of("grid","gallery","kanban","calendar","dashboard").contains(v.path("kind").asText()))throw bad();
            JsonNode cols=v.path("columns"),filters=v.path("filters");if(!cols.isArray()||cols.size()>40||!filters.isArray()||filters.size()>10)throw bad();
            Set<String> colIds=new HashSet<>();for(JsonNode c:cols){keys(c,Set.of("id","width","hidden"));if(!fields.containsKey(id(c.path("id")))||!colIds.add(c.path("id").asText())||!c.path("width").isIntegralNumber()||c.path("width").asInt()<64||c.path("width").asInt()>600||!c.path("hidden").isBoolean())throw bad();}
            for(JsonNode f:filters){keys(f,Set.of("field","op","value"));if(!fields.containsKey(id(f.path("field")))||!Set.of("contains","equals","empty","gt","lt").contains(f.path("op").asText())||!text(f.path("value"),1024))throw bad();}
            for(String k:List.of("sort","group"))if(!text(v.path(k),36)||(!v.path(k).asText().isEmpty()&&!fields.containsKey(v.path(k).asText())))throw bad();
            if(!Set.of("asc","desc").contains(v.path("direction").asText())||!Set.of("all","any").contains(v.path("logic").asText())||!Set.of("compact","normal","comfortable").contains(v.path("density").asText())||!Set.of("small","medium","large").contains(v.path("cardSize").asText()))throw bad();
        }
        if(!viewIds.contains(id(d.path("activeView"))))throw bad();
        String raw=d.toString();if(raw.getBytes(StandardCharsets.UTF_8).length>1048576)throw bad();return raw;
    }
    @GetMapping public List<Summary> list(@AuthenticationPrincipal Jwt jwt){return jdbc.query("SELECT id,version,payload_json::jsonb->>'name',archived FROM workspace_table WHERE owner_id=? ORDER BY updated_at DESC",(rs,i)->new Summary(rs.getObject(1,UUID.class),rs.getLong(2),rs.getString(3),rs.getBoolean(4)),owner(jwt));}
    @GetMapping("/{id}") public Table get(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return read(owner(jwt),id);}
    private Table read(UUID owner,UUID id){return jdbc.query("SELECT version,payload_json,archived FROM workspace_table WHERE owner_id=? AND id=?",(rs,i)->new Table(id,rs.getLong(1),parse(rs.getString(2)),rs.getBoolean(3)),owner,id).stream().findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Table unavailable"));}
    @PutMapping("/{id}") @Transactional public Table write(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Write req){
        UUID owner=owner(jwt);String raw=validate(req.data());int n;
        if(req.expectedVersion()==0){jdbc.query("SELECT pg_advisory_xact_lock(hashtext(?))",rs->{},owner.toString());Integer count=jdbc.queryForObject("SELECT COUNT(*) FROM workspace_table WHERE owner_id=?",Integer.class,owner);if(count!=null&&count>=100)throw bad();n=jdbc.update("INSERT INTO workspace_table(id,owner_id,version,payload_json) VALUES(?,?,1,?) ON CONFLICT DO NOTHING",id,owner,raw);}
        else n=jdbc.update("UPDATE workspace_table SET payload_json=?,version=version+1,updated_at=now() WHERE id=? AND owner_id=? AND version=? AND NOT archived AND version<9223372036854775807",raw,id,owner,req.expectedVersion());
        if(n!=1)throw conflict();return read(owner,id);
    }
    @PostMapping("/{id}/archive") @Transactional public Table archive(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Archive req){if(jdbc.update("UPDATE workspace_table SET archived=?,version=version+1,updated_at=now() WHERE id=? AND owner_id=? AND version=? AND version<9223372036854775807",req.archived(),id,owner(jwt),req.expectedVersion())!=1)throw conflict();return read(owner(jwt),id);}
}
