package it.ddone.simplenotes.task;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** Distinct from a version conflict: a stale client must upgrade, not rebase. */
public class ClientUpgradeRequiredException extends ResponseStatusException {
    public ClientUpgradeRequiredException() {
        super(HttpStatus.UPGRADE_REQUIRED, "CLIENT_UPGRADE_REQUIRED");
    }
}
