package it.ddone.simplenotes.task;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ClientUpgradeAdvice {
    @ExceptionHandler(ClientUpgradeRequiredException.class)
    public ResponseEntity<Map<String, String>> handle(ClientUpgradeRequiredException exception) {
        return ResponseEntity.status(HttpStatus.UPGRADE_REQUIRED)
            .body(Map.of("code", "CLIENT_UPGRADE_REQUIRED",
                "message", "Update Simple Notes before editing this task."));
    }
}
