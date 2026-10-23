package it.ddone.simplenotes.task;

import java.sql.*;
import java.time.Instant;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import static org.junit.jupiter.api.Assertions.*;

/** Test upgrades an actual populated V6 database to V7; no production data involved. */
class DueMigrationTest {
    @Test
    void v7PreservesExistingInstantsAndNullsWithoutInferringMidnight() throws Exception {
        try (PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:17-alpine")) {
            postgres.start();
            var oldFlyway = Flyway.configure()
                .dataSource(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())
                .target("6").load();
            oldFlyway.migrate();
            UUID userId = UUID.randomUUID();
            UUID withDue = UUID.randomUUID();
            UUID withoutDue = UUID.randomUUID();
            Instant midnight = Instant.parse("2026-10-24T22:00:00Z");
            try (Connection connection = DriverManager.getConnection(postgres.getJdbcUrl(),
                    postgres.getUsername(), postgres.getPassword())) {
                try (PreparedStatement user = connection.prepareStatement(
                        "INSERT INTO app_user(id,google_subject,email) VALUES (?,?,?)")) {
                    user.setObject(1, userId);
                    user.setString(2, UUID.randomUUID().toString());
                    user.setString(3, "migration-test@example.com");
                    user.executeUpdate();
                }
                try (PreparedStatement task = connection.prepareStatement(
                        "INSERT INTO task(id,owner_id,title,due_at) VALUES (?,?,?,?)")) {
                    task.setObject(1, withDue);
                    task.setObject(2, userId);
                    task.setString(3, "Possibly midnight");
                    task.setTimestamp(4, Timestamp.from(midnight));
                    task.executeUpdate();
                    task.setObject(1, withoutDue);
                    task.setObject(2, userId);
                    task.setString(3, "No due");
                    task.setNull(4, Types.TIMESTAMP_WITH_TIMEZONE);
                    task.executeUpdate();
                }
            }
            Flyway.configure().dataSource(postgres.getJdbcUrl(),
                postgres.getUsername(), postgres.getPassword()).load().migrate();
            try (Connection connection = DriverManager.getConnection(postgres.getJdbcUrl(),
                    postgres.getUsername(), postgres.getPassword());
                 PreparedStatement query = connection.prepareStatement(
                    "SELECT due_kind, due_at, due_date, due_time, due_timezone, due_offset_seconds FROM task WHERE id=?")) {
                query.setObject(1, withDue);
                try (ResultSet rs = query.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals("legacy", rs.getString(1));
                    assertEquals(midnight, rs.getTimestamp(2).toInstant());
                    for (int i = 3; i <= 6; i++) assertNull(rs.getObject(i));
                }
                query.setObject(1, withoutDue);
                try (ResultSet rs = query.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals("none", rs.getString(1));
                    for (int i = 2; i <= 6; i++) assertNull(rs.getObject(i));
                }
            }
        }
    }
}
