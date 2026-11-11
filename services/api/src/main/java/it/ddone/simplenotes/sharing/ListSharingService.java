package it.ddone.simplenotes.sharing;

import it.ddone.simplenotes.sync.SyncService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Explicit, JWT-only read-only access to a single owner's active task list.
 * NEVER proxies a collaborator through /sync: that ledger and its account
 * cursor must remain scoped exclusively to the original owner.
 */
@Service
public class ListSharingService {
    public record IssuedInvitation(UUID id, String token, Instant expiresAt) {}
    public record PendingInvitation(UUID id, Instant createdAt, Instant expiresAt) {}
    public record SharedList(UUID id, String title, String role, Instant updatedAt) {}
    public record Member(UUID id, String displayName, Instant acceptedAt,
        String role) {}
    public record SharedTask(UUID id, String title, String description,
        int priority, Instant dueAt, String dueKind, LocalDate dueDate,
        LocalTime dueTime, String dueTimezone, Integer dueOffsetSeconds,
        Instant completedAt, long version) {}
    public record Snapshot(UUID listId, String title, boolean readOnly,
        List<SharedTask> tasks, Integer nextOffset) {}

    private record Invitation(UUID id, UUID owner, UUID list, Instant expires,
        Instant revoked, UUID redeemed) {}
    private record ListAccess(UUID owner, String title, String role) {}

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int PAGE_SIZE = 50;
    private final JdbcTemplate jdbc;
    private final SyncService sync;

    public ListSharingService(JdbcTemplate jdbc, SyncService sync) {
        this.jdbc = jdbc;
        this.sync = sync;
    }

    private static ResponseStatusException missing() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "List unavailable");
    }
    private static ResponseStatusException conflict() {
        return new ResponseStatusException(HttpStatus.CONFLICT, "Invitation unavailable");
    }
    private static Instant time(java.sql.ResultSet rs, String field)
            throws java.sql.SQLException {
        Timestamp value = rs.getTimestamp(field);
        return value == null ? null : value.toInstant();
    }
    private static String digest(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(token.getBytes(StandardCharsets.US_ASCII)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private void ownerHasActiveList(UUID owner, UUID list) {
        Integer count = jdbc.queryForObject(
            "SELECT COUNT(*) FROM task_list WHERE id=? AND owner_id=? " +
            "AND deleted_at IS NULL", Integer.class, list, owner);
        if (count == null || count == 0) throw missing();
    }

    @Transactional
    public IssuedInvitation issue(UUID owner, UUID list) {
        // Serialize issuing/revocation with owner writes to list via /sync.
        sync.lockAccount(owner);
        ownerHasActiveList(owner, list);
        Integer active = jdbc.queryForObject(
            "SELECT COUNT(*) FROM list_share_invitation WHERE owner_id=? " +
            "AND list_id=? AND revoked_at IS NULL AND redeemed_at IS NULL " +
            "AND expires_at > now()", Integer.class, owner, list);
        if (active != null && active >= 5) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Too many active invitation links");
        }
        byte[] entropy = new byte[32];
        RANDOM.nextBytes(entropy);
        String token = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(entropy);
        Instant now = Instant.now();
        Instant expires = now.plus(7, ChronoUnit.DAYS);
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO list_share_invitation " +
            "(id,owner_id,list_id,token_hash,created_at,expires_at) " +
            "VALUES (?,?,?,?,?,?)",
            id, owner, list, digest(token), Timestamp.from(now),
            Timestamp.from(expires));
        // Raw token is returned precisely once. DB stores only its digest.
        return new IssuedInvitation(id, token, expires);
    }

    @Transactional(readOnly = true)
    public List<PendingInvitation> invitations(UUID owner, UUID list) {
        ownerHasActiveList(owner, list);
        return jdbc.query(
            "SELECT id,created_at,expires_at FROM list_share_invitation " +
            "WHERE owner_id=? AND list_id=? AND revoked_at IS NULL " +
            "AND redeemed_at IS NULL AND expires_at > now() " +
            "ORDER BY created_at DESC LIMIT 10",
            (rs, row) -> new PendingInvitation(
                (UUID) rs.getObject("id"), time(rs,"created_at"),
                time(rs,"expires_at")), owner, list);
    }

    @Transactional
    public void revokeInvitation(UUID owner, UUID list, UUID id) {
        sync.lockAccount(owner);
        ownerHasActiveList(owner, list);
        int affected = jdbc.update(
            "UPDATE list_share_invitation SET revoked_at=now() " +
            "WHERE id=? AND owner_id=? AND list_id=? " +
            "AND revoked_at IS NULL AND redeemed_at IS NULL",
            id, owner, list);
        if (affected != 1) throw missing();
    }

    @Transactional
    public SharedList accept(UUID member, String token) {
        if (token == null || !token.matches("[A-Za-z0-9_-]{43}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Invalid invitation token");
        }
        List<Invitation> found = jdbc.query(
            "SELECT id,owner_id,list_id,expires_at,revoked_at,redeemed_by " +
            "FROM list_share_invitation WHERE token_hash=? FOR UPDATE",
            (rs, row) -> new Invitation((UUID) rs.getObject("id"),
                (UUID) rs.getObject("owner_id"),
                (UUID) rs.getObject("list_id"), time(rs,"expires_at"),
                time(rs,"revoked_at"), (UUID) rs.getObject("redeemed_by")),
            digest(token));
        if (found.isEmpty()) throw missing();
        Invitation invitation = found.get(0);
        if (invitation.revoked() != null || invitation.redeemed() != null ||
                !invitation.expires().isAfter(Instant.now()) ||
                invitation.owner().equals(member)) throw conflict();

        // Row-lock the active list to serialize capacity across distinct
        // invitation links and reject shares of soft-deleted lists.
        List<String> titles = jdbc.query(
            "SELECT title FROM task_list WHERE id=? AND owner_id=? " +
            "AND deleted_at IS NULL FOR UPDATE",
            (rs,row) -> rs.getString(1),
            invitation.list(), invitation.owner());
        if (titles.isEmpty()) throw conflict();
        Integer members = jdbc.queryForObject(
            "SELECT COUNT(*) FROM list_share_member WHERE list_id=?",
            Integer.class, invitation.list());
        if (members != null && members >= 20) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "List sharing capacity reached");
        }
        int added = jdbc.update(
            "INSERT INTO list_share_member (list_id,owner_id,member_id,role) " +
            "VALUES (?,?,?,'VIEWER') ON CONFLICT DO NOTHING",
            invitation.list(), invitation.owner(), member);
        if (added != 1) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Already a collaborator");
        }
        jdbc.update("UPDATE list_share_invitation SET " +
            "redeemed_by=?,redeemed_at=now() WHERE id=?",
            member, invitation.id());
        Timestamp updatedAt = jdbc.queryForObject(
            "SELECT updated_at FROM task_list WHERE id=?",
            Timestamp.class, invitation.list());
        return new SharedList(invitation.list(), titles.get(0), "VIEWER",
            updatedAt.toInstant());
    }

    @Transactional(readOnly = true)
    public List<SharedList> mySharedLists(UUID member) {
        return jdbc.query(
            "SELECT l.id,l.title,l.updated_at,m.role FROM list_share_member m " +
            "JOIN task_list l ON l.id=m.list_id AND l.owner_id=m.owner_id " +
            "WHERE m.member_id=? AND l.deleted_at IS NULL " +
            "ORDER BY m.accepted_at DESC LIMIT 100",
            (rs,row) -> new SharedList((UUID) rs.getObject("id"),
                rs.getString("title"), rs.getString("role"),
                time(rs,"updated_at")), member);
    }

    @Transactional(readOnly = true)
    public Snapshot snapshot(UUID member, UUID list, int offset) {
        if (offset < 0 || offset > 10000) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Invalid page offset");
        }
        List<ListAccess> access = jdbc.query(
            "SELECT l.owner_id,l.title,m.role FROM list_share_member m " +
            "JOIN task_list l ON l.id=m.list_id AND l.owner_id=m.owner_id " +
            "WHERE m.member_id=? AND m.list_id=? AND m.role IN ('VIEWER','EDITOR') " +
            "AND l.deleted_at IS NULL",
            (rs,row) -> new ListAccess((UUID) rs.getObject("owner_id"),
                rs.getString("title"), rs.getString("role")), member, list);
        if (access.isEmpty()) throw missing();
        ListAccess shared = access.get(0);
        List<SharedTask> data = jdbc.query(
            "SELECT id,title,description,priority,due_at,due_kind,due_date," +
            "due_time,due_timezone,due_offset_seconds,completed_at,version " +
            "FROM task WHERE owner_id=? AND list_id=? AND deleted_at IS NULL " +
            "ORDER BY created_at DESC,id DESC LIMIT ? OFFSET ?",
            (rs,row) -> new SharedTask((UUID)rs.getObject("id"),
                rs.getString("title"),rs.getString("description"),
                rs.getInt("priority"),time(rs,"due_at"),rs.getString("due_kind"),
                rs.getObject("due_date", LocalDate.class),
                rs.getObject("due_time", LocalTime.class),
                rs.getString("due_timezone"),
                (Integer) rs.getObject("due_offset_seconds"),
                time(rs,"completed_at"),rs.getLong("version")),
            shared.owner(),list,PAGE_SIZE+1,offset);
        boolean more = data.size() > PAGE_SIZE;
        var page = more ? List.copyOf(data.subList(0, PAGE_SIZE)) :
            List.copyOf(data);
        return new Snapshot(list, shared.title(),
            !"EDITOR".equals(shared.role()), page,
            more ? offset + PAGE_SIZE : null);
    }

    @Transactional(readOnly = true)
    public List<Member> members(UUID owner, UUID list) {
        ownerHasActiveList(owner,list);
        return jdbc.query(
            "SELECT m.member_id,u.display_name,m.accepted_at,m.role " +
            "FROM list_share_member m JOIN app_user u ON u.id=m.member_id " +
            "WHERE m.list_id=? AND m.owner_id=? " +
            "ORDER BY m.accepted_at DESC LIMIT 20",
            (rs,row) -> new Member((UUID) rs.getObject("member_id"),
                rs.getString("display_name"),time(rs,"accepted_at"),
                rs.getString("role")),
            list,owner);
    }

    /** Only the owning account may promote an accepted member. */
    @Transactional
    public Member setMemberRole(UUID owner, UUID list, UUID member,
            String role) {
        if (!Set.of("VIEWER", "EDITOR").contains(role)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Invalid sharing role");
        }
        sync.lockAccount(owner);
        ownerHasActiveList(owner, list);
        List<Member> found = jdbc.query(
            "SELECT m.member_id,u.display_name,m.accepted_at,m.role " +
            "FROM list_share_member m JOIN app_user u ON u.id=m.member_id " +
            "WHERE m.owner_id=? AND m.list_id=? AND m.member_id=?",
            (rs, i) -> new Member((UUID) rs.getObject("member_id"),
                rs.getString("display_name"),time(rs, "accepted_at"),
                rs.getString("role")), owner, list, member);
        if (found.size() != 1) throw missing();
        Member current = found.get(0);
        if (!role.equals(current.role())) {
            jdbc.update(
                "UPDATE list_share_member SET role=? " +
                "WHERE owner_id=? AND list_id=? AND member_id=?",
                role, owner, list, member);
            jdbc.update("INSERT INTO list_share_audit " +
                "(list_id,owner_id,actor_id,target_member_id,action,detail) " +
                "VALUES (?,?,?,?,'ROLE_CHANGE',?)",
                list, owner, owner, member, current.role() + "->" + role);
        }
        return new Member(member, current.displayName(), current.acceptedAt(),
            role);
    }

    @Transactional
    public void removeMember(UUID owner, UUID list, UUID member) {
        sync.lockAccount(owner);
        ownerHasActiveList(owner,list);
        int affected = jdbc.update(
            "DELETE FROM list_share_member WHERE list_id=? " +
            "AND owner_id=? AND member_id=?",
            list,owner,member);
        if (affected != 1) throw missing();
    }

    @Transactional
    public void leave(UUID member, UUID list) {
        List<UUID> owners = jdbc.query(
            "SELECT owner_id FROM list_share_member " +
            "WHERE list_id=? AND member_id=?",
            (rs, i) -> (UUID) rs.getObject(1), list, member);
        if (owners.size() != 1) throw missing();
        sync.lockAccount(owners.get(0));
        int affected = jdbc.update(
            "DELETE FROM list_share_member WHERE list_id=? AND member_id=? " +
            "AND owner_id=?",
            list, member, owners.get(0));
        if (affected != 1) throw missing();
    }
}
