package it.ddone.simplenotes.calendar;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

/** Never follows redirects containing OAuth credentials; bounded JSON reads. */
@Component
public class CalendarHttpGateway {
    private final HttpClient client = HttpClient.newBuilder()
        .followRedirects(HttpClient.Redirect.NEVER)
        .connectTimeout(Duration.ofSeconds(5)).build();
    private final ObjectMapper json;

    public CalendarHttpGateway(ObjectMapper json) { this.json = json; }

    static String form(Map<String, String> values) {
        return values.entrySet().stream()
            .map(e -> URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8)
                + "=" + URLEncoder.encode(e.getValue(), StandardCharsets.UTF_8))
            .collect(Collectors.joining("&"));
    }

    public JsonNode token(URI endpoint, Map<String, String> values) {
        HttpRequest request = HttpRequest.newBuilder(endpoint)
            .timeout(Duration.ofSeconds(12))
            .header("Content-Type", "application/x-www-form-urlencoded")
            .header("Accept", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(form(values))).build();
        return send(request);
    }

    public JsonNode read(URI endpoint, String accessToken, boolean microsoft) {
        HttpRequest.Builder builder = HttpRequest.newBuilder(endpoint)
            .timeout(Duration.ofSeconds(12)).header("Accept", "application/json")
            .header("Authorization", "Bearer " + accessToken).GET();
        if (microsoft) builder.header("Prefer", "outlook.timezone=\"UTC\"");
        return send(builder.build());
    }

    private JsonNode send(HttpRequest request) {
        try {
            HttpResponse<InputStream> response =
                client.send(request, HttpResponse.BodyHandlers.ofInputStream());
            try (InputStream body = response.body()) {
                byte[] bytes = body.readNBytes(256 * 1024 + 1);
                if (bytes.length > 256 * 1024 || response.statusCode() < 200
                        || response.statusCode() >= 300) {
                    throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                        "Calendar provider rejected the request");
                }
                JsonNode root = json.readTree(bytes);
                if (root == null || !root.isObject()) {
                    throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                        "Calendar provider sent an invalid response");
                }
                return root;
            }
        } catch (ResponseStatusException ex) { throw ex; }
        catch (Exception ex) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                "Calendar provider is unavailable");
        }
    }
}
