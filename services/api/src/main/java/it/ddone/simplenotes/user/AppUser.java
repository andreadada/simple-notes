package it.ddone.simplenotes.user;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "app_user")
public class AppUser {
    @Id public UUID id;
    @Column(name = "google_subject", nullable = false, unique = true) public String googleSubject;
    @Column(nullable = false) public String email;
    @Column(name = "display_name") public String displayName;
    @Column(name = "photo_url") public String photoUrl;
    @Column(name = "created_at", nullable = false) public Instant createdAt;

    protected AppUser() {}
    public AppUser(String googleSubject, String email, String displayName) {
        this.id = UUID.randomUUID();
        this.googleSubject = googleSubject;
        this.email = email;
        this.displayName = displayName;
        this.createdAt = Instant.now();
    }
}
