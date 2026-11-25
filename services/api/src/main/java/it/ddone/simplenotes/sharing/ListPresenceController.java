
package it.ddone.simplenotes.sharing;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Ephemeral presence, not collaboration writes. No uncommitted content or tokens. */
@RestController
@RequestMapping("/api/v1/sharing/lists/{listId}/presence")
public class ListPresenceController {
    private record Person(UUID id,String displayName,String role) {}
    private record Key(UUID listId,UUID actor) {}
    private record Touch(UUID taskId,String field,Instant until) {}
    public record Heartbeat(UUID taskId,String field) {}
    public record Presence(String name,String role,UUID taskId,String field,boolean self) {}
    private final Map<Key,Touch> active=new HashMap<>();
    private final JdbcTemplate jdbc;
    public ListPresenceController(JdbcTemplate jdbc){this.jdbc=jdbc;}
    @PostMapping
    public synchronized List<Presence> heartbeat(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID listId,@RequestBody Heartbeat request){
        UUID actor=UUID.fromString(jwt.getSubject());
        // Access and returned identities are checked against CURRENT list ACL.
        var people=jdbc.query("""
          SELECT u.id,u.display_name,'OWNER' FROM task_list l JOIN app_user u ON u.id=l.owner_id
          WHERE l.id=? AND l.deleted_at IS NULL
          UNION ALL
          SELECT u.id,u.display_name,m.role FROM list_share_member m JOIN task_list l ON l.id=m.list_id AND l.owner_id=m.owner_id
          JOIN app_user u ON u.id=m.member_id WHERE m.list_id=? AND l.deleted_at IS NULL
          """,(rs,i)->new Person(rs.getObject(1,UUID.class),rs.getString(2),rs.getString(3)),listId,listId);
        if(people.stream().noneMatch(p->p.id().equals(actor)))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"List unavailable");
        UUID task=request.taskId();
        if(task!=null){
            Integer count=jdbc.queryForObject("SELECT count(*) FROM task t JOIN task_list l ON l.id=t.list_id AND l.owner_id=t.owner_id WHERE l.id=? AND t.id=? AND t.deleted_at IS NULL AND l.deleted_at IS NULL",Integer.class,listId,task);
            if(count==null||count!=1)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Task not in list");
        }
        String field=request.field();
        if(field!=null&&(task==null||!Set.of("title","description","priority","completed").contains(field)))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid cell");
        Instant now=Instant.now();active.entrySet().removeIf(e->!e.getValue().until().isAfter(now));
        Key key=new Key(listId,actor);
        if(active.size()<10000||active.containsKey(key))active.put(key,new Touch(task,field,now.plusSeconds(35)));
        List<Presence> result=new ArrayList<>();
        for(Person p:people){Touch touch=active.get(new Key(listId,p.id()));if(touch!=null)result.add(new Presence(p.displayName(),p.role(),touch.taskId(),touch.field(),actor.equals(p.id())));}
        return List.copyOf(result);
    }
}
