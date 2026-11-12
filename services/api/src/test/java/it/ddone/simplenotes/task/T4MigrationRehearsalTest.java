package it.ddone.simplenotes.task;

import static org.junit.jupiter.api.Assertions.*;

import java.sql.*;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;

/**
 * T4 staging rehearsal: upgrade a populated V6 PostgreSQL through V7 and V8 and prove
 * that user, task, note, list and sync logs survive with identifiers intact.
 * A disposable Testcontainers database is used; never connects to Coolify.
 */
class T4MigrationRehearsalTest {
    @Test
    void populatedV6KeepsSyncOperationIdsAndEnforcesDueConstraints() throws Exception {
        try (PostgreSQLContainer<?> postgres =
                 new PostgreSQLContainer<>("postgres:17-alpine")) {
            postgres.start();
            var dataSource = Flyway.configure().dataSource(
                    postgres.getJdbcUrl(), postgres.getUsername(),
                    postgres.getPassword());
            dataSource.target("6").load().migrate();

            var owner = UUID.randomUUID();
            var list = UUID.randomUUID();
            var task = UUID.randomUUID();
            var note = UUID.randomUUID();
            var operation = UUID.randomUUID();
            long change;
            String payload = "{\"id\":\"" + task + "\",\"dueAt\":\"2026-10-24T22:00:00Z\"}";
            try (Connection db = DriverManager.getConnection(
                    postgres.getJdbcUrl(), postgres.getUsername(),
                    postgres.getPassword())) {
                try (PreparedStatement ps = db.prepareStatement(
                    "INSERT INTO app_user(id,google_subject,email) VALUES (?,?,?)")) {
                    ps.setObject(1, owner);
                    ps.setString(2, UUID.randomUUID().toString());
                    ps.setString(3, "t4-fixture@example.invalid");
                    assertEquals(1, ps.executeUpdate());
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "INSERT INTO task_list(id,owner_id,title,version) VALUES (?,?,?,?)")) {
                    ps.setObject(1, list);
                    ps.setObject(2, owner);
                    ps.setString(3, "Fixture List");
                    ps.setLong(4, 3);
                    ps.executeUpdate();
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "INSERT INTO task(id,owner_id,list_id,title,version,due_at,"
                        + "tags_json,subtasks_json) VALUES (?,?,?,?,?,?,?,?)")) {
                    ps.setObject(1, task);
                    ps.setObject(2, owner);
                    ps.setObject(3, list);
                    ps.setString(4, "Existing due");
                    ps.setLong(5, 4);
                    ps.setTimestamp(6,
                        Timestamp.from(java.time.Instant.parse("2026-10-24T22:00:00Z")));
                    ps.setString(7, "[\"important\"]");
                    ps.setString(8, "[]");
                    ps.executeUpdate();
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "INSERT INTO note(id,owner_id,title,body,version) VALUES (?,?,?,?,?)")) {
                    ps.setObject(1, note);
                    ps.setObject(2, owner);
                    ps.setString(3, "Fixture Note");
                    ps.setString(4, "Retain original text");
                    ps.setLong(5, 8);
                    ps.executeUpdate();
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "INSERT INTO sync_change(owner_id,entity_type,entity_id,"
                    + "payload,deleted,version) VALUES (?,?,?,?,?,?) RETURNING id")) {
                    ps.setObject(1, owner);
                    ps.setString(2, "task");
                    ps.setObject(3, task);
                    ps.setString(4, payload);
                    ps.setBoolean(5, false);
                    ps.setLong(6, 4);
                    try (ResultSet rs = ps.executeQuery()) {
                        assertTrue(rs.next());
                        change = rs.getLong(1);
                    }
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "INSERT INTO sync_operation(id,owner_id,entity_type,entity_id,"
                    + "resulting_version,change_id) VALUES (?,?,?,?,?,?)")) {
                    ps.setObject(1, operation);
                    ps.setObject(2, owner);
                    ps.setString(3, "task");
                    ps.setObject(4, task);
                    ps.setLong(5, 4);
                    ps.setLong(6, change);
                    ps.executeUpdate();
                }
            }

            var migrated = Flyway.configure().dataSource(
                postgres.getJdbcUrl(), postgres.getUsername(),
                postgres.getPassword()).load();
            migrated.migrate();
            migrated.validate();
            assertEquals("18", migrated.info().current().getVersion().toString());
            // Calendar links are additive and empty after migrating existing accounts.
            try (Connection db = DriverManager.getConnection(
                    postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())) {
                for (String name : java.util.List.of("calendar_oauth_attempt", "calendar_oauth_connection")) {
                    try (PreparedStatement ps = db.prepareStatement("SELECT COUNT(*) FROM " + name);
                         ResultSet rs = ps.executeQuery()) {
                        assertTrue(rs.next());
                        assertEquals(0, rs.getLong(1));
                    }
                }
            }

            try (Connection db = DriverManager.getConnection(
                    postgres.getJdbcUrl(), postgres.getUsername(),
                    postgres.getPassword())) {
                // V12 is additive: it creates an empty, owner-bound
                // preferences table without migrating or replaying tasks.
                try (PreparedStatement ps = db.prepareStatement(
                    "SELECT COUNT(*) FROM task_action_catalog");
                     ResultSet rs = ps.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(0, rs.getLong(1));
                }
                // V13 also adds an empty user-template definition catalog;
                // no historical tasks, notes or outbox rows are migrated.
                try (PreparedStatement ps = db.prepareStatement(
                    "SELECT COUNT(*) FROM user_template_catalog");
                     ResultSet rs = ps.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(0, rs.getLong(1));
                }
                // V14–V17 add attachments and sharing without rewriting
                // historical task, note, account, or sync rows.
                try (PreparedStatement audit = db.prepareStatement(
                    "SELECT COUNT(*) FROM list_share_audit");
                     ResultSet rows = audit.executeQuery()) {
                    assertTrue(rows.next());
                    assertEquals(0, rows.getLong(1));
                }
                // V14/V15/V16 add attachments and read-only sharing metadata.
                try (PreparedStatement shared = db.prepareStatement(
                    "SELECT COUNT(*) FROM list_share_member");
                     ResultSet rows = shared.executeQuery()) {
                    assertTrue(rows.next());
                    assertEquals(0, rows.getLong(1));
                }
                try (PreparedStatement invitations = db.prepareStatement(
                    "SELECT COUNT(*) FROM list_share_invitation");
                     ResultSet rows = invitations.executeQuery()) {
                    assertTrue(rows.next());
                    assertEquals(0, rows.getLong(1));
                }
                // V14/V15 add attachment metadata and a durable deletion queue,
                // preserving all existing app data.
                try (PreparedStatement pending = db.prepareStatement(
                    "SELECT COUNT(*) FROM attachment_object_delete_queue");
                        ResultSet rows = pending.executeQuery()) {
                    assertTrue(rows.next());
                    assertEquals(0, rows.getLong(1));
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "SELECT COUNT(*) FROM note_attachment");
                     ResultSet rs = ps.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(0, rs.getLong(1));
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "SELECT due_kind,due_at,version,tags_json,list_id,block_start_at,block_end_at,block_timezone,blocks_json "
                    + "FROM task WHERE id=?")) {
                    ps.setObject(1, task);
                    try (ResultSet rs = ps.executeQuery()) {
                        assertTrue(rs.next());
                        assertEquals("legacy", rs.getString(1));
                        assertEquals(java.time.Instant.parse("2026-10-24T22:00:00Z"),
                            rs.getTimestamp(2).toInstant());
                        assertEquals(4, rs.getLong(3));
                        assertEquals("[\"important\"]", rs.getString(4));
                        assertEquals(list, rs.getObject(5, UUID.class));
                        assertNull(rs.getTimestamp(6));
                        assertNull(rs.getTimestamp(7));
                        assertNull(rs.getString(8));
                        assertEquals("[]", rs.getString(9));
                    }
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "SELECT body,version FROM note WHERE id=?")) {
                    ps.setObject(1, note);
                    try (ResultSet rs = ps.executeQuery()) {
                        assertTrue(rs.next());
                        assertEquals("Retain original text", rs.getString(1));
                        assertEquals(8, rs.getLong(2));
                    }
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "SELECT payload,version FROM sync_change WHERE id=?")) {
                    ps.setLong(1, change);
                    try (ResultSet rs = ps.executeQuery()) {
                        assertTrue(rs.next());
                        assertEquals(payload, rs.getString(1));
                        assertEquals(4, rs.getLong(2));
                    }
                }
                try (PreparedStatement ps = db.prepareStatement(
                    "SELECT resulting_version,change_id,request_fingerprint " +
                    "FROM sync_operation WHERE id=?")) {
                    ps.setObject(1, operation);
                    try (ResultSet rs = ps.executeQuery()) {
                        assertTrue(rs.next());
                        assertEquals(4, rs.getLong(1));
                        assertEquals(change, rs.getLong(2));
                        // V11 must NOT manufacture or rewrite fingerprints of
                        // operations that already existed on V6.
                        assertNull(rs.getString(3));
                    }
                }
                // V7 constraints forbid a date-only marker with a legacy instant.
                try (PreparedStatement ps = db.prepareStatement(
                    "UPDATE task SET due_kind='date',due_date=DATE '2026-10-26' WHERE id=?")) {
                    ps.setObject(1, task);
                    assertThrows(SQLException.class, ps::executeUpdate);
                }
            }
        }
    }
}
