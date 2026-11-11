package it.ddone.simplenotes;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class SimpleNotesApplication {
    public static void main(String[] args) {
        SpringApplication.run(SimpleNotesApplication.class, args);
    }
}
