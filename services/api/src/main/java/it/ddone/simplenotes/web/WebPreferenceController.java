
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

@RestController
@RequestMapping("/api/v1/web/preferences")
public class WebPreferenceController {
    private static final Set<String> MAPS = Set.of("views","customViews","viewOptions","dashboards","gridColumns");
    private static final Set<String> ARRAYS = Set.of("habits","countdowns","customFields");
    private final JdbcTemplate jdbc;
    private final ObjectMapper json;
    public WebPreferenceController(JdbcTemplate jdbc, ObjectMapper json) { this.jdbc=jdbc; this.json=json; }
    public record Snapshot(String domain,long version,JsonNode value) {}
    public record Replace(@NotNull @Min(0) Long expectedVersion,@NotNull JsonNode value) {}
    private UUID owner(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }
    private JsonNode parse(String value) { try { return json.readTree(value); } catch(Exception e) { throw new IllegalStateException("Invalid stored web preference",e); } }
    private static ResponseStatusException invalid() { return new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid web preference"); }
    private static void validateTree(JsonNode n,int depth) {
        if(depth>12 || n.isTextual() && n.textValue().length()>4096 || n.size()>2000) throw invalid();
        if(n.isObject()) { var it=n.fields(); while(it.hasNext()) { var e=it.next(); if(e.getKey().length()>240 || Set.of("__proto__","constructor","prototype").contains(e.getKey())) throw invalid(); validateTree(e.getValue(),depth+1); } }
        else if(n.isArray()) for(JsonNode child:n) validateTree(child,depth+1);
    }
    private static String validate(String domain,JsonNode n) {
        if(n==null || n.isNull() || !(domain.equals("theme") && n.isTextual() && Set.of("light","dark","system").contains(n.textValue()) || MAPS.contains(domain) && n.isObject() || ARRAYS.contains(domain) && n.isArray() || domain.equals("automationEnabled") && n.isBoolean())) throw invalid();
        validateTree(n,0);
        String result=n.toString();
        if(result.getBytes(StandardCharsets.UTF_8).length>262144) throw invalid();
        return result;
    }
    @GetMapping
    public List<Snapshot> read(@AuthenticationPrincipal Jwt jwt) {
        return jdbc.query("SELECT domain,version,payload_json FROM web_preference WHERE owner_id=? ORDER BY domain",(rs,i)->new Snapshot(rs.getString(1),rs.getLong(2),parse(rs.getString(3))),owner(jwt));
    }
    @PutMapping("/{domain}")
    @Transactional
    public Snapshot replace(@AuthenticationPrincipal Jwt jwt,@PathVariable String domain,@Valid @RequestBody Replace req) {
        String value=validate(domain,req.value());
        UUID owner=owner(jwt);
        int count;
        if(req.expectedVersion()==0) count=jdbc.update("INSERT INTO web_preference(owner_id,domain,payload_json,version) VALUES(?,?,?,1) ON CONFLICT DO NOTHING",owner,domain,value);
        else count=jdbc.update("UPDATE web_preference SET payload_json=?,version=version+1,updated_at=now() WHERE owner_id=? AND domain=? AND version=? AND version<9223372036854775807",value,owner,domain,req.expectedVersion());
        if(count!=1) throw new ResponseStatusException(HttpStatus.CONFLICT,"Web preference revision changed");
        return new Snapshot(domain,req.expectedVersion()+1,req.value());
    }
}
