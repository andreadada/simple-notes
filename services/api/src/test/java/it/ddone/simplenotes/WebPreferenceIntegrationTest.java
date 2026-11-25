package it.ddone.simplenotes;
import it.ddone.simplenotes.user.*;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@SpringBootTest @AutoConfigureMockMvc @Testcontainers
class WebPreferenceIntegrationTest {
 @Container static final PostgreSQLContainer<?> pg=new PostgreSQLContainer<>("postgres:17-alpine");
 @DynamicPropertySource static void props(DynamicPropertyRegistry p){p.add("spring.datasource.url",pg::getJdbcUrl);p.add("spring.datasource.username",pg::getUsername);p.add("spring.datasource.password",pg::getPassword);p.add("app.google.client-ids",()->"test-google-client");p.add("app.jwt.secret-base64",()->"QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVoxMjM0NTY=");}
 @Autowired MockMvc mvc; @Autowired AppUserRepository users; @Autowired JwtEncoder encoder;
 String token(){var u=users.save(new AppUser("web-"+UUID.randomUUID(),"web@example.com","Web"));var now=Instant.now();var claims=JwtClaimsSet.builder().issuer("simple-notes-api").audience(List.of("simple-notes")).subject(u.id.toString()).issuedAt(now).expiresAt(now.plusSeconds(600)).build();return "Bearer "+encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(),claims)).getTokenValue();}
 @Test void privateVersionedPreferences() throws Exception {
  String path="/api/v1/web/preferences",a=token(),b=token();
  mvc.perform(get(path)).andExpect(status().isUnauthorized());
  mvc.perform(put(path+"/theme").header("Authorization",a).contentType(MediaType.APPLICATION_JSON).content("{\"expectedVersion\":0,\"value\":\"dark\"}")).andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));
  mvc.perform(put(path+"/theme").header("Authorization",a).contentType(MediaType.APPLICATION_JSON).content("{\"expectedVersion\":0,\"value\":\"light\"}")).andExpect(status().isConflict());
  mvc.perform(get(path).header("Authorization",b)).andExpect(jsonPath("$.length()").value(0));
  mvc.perform(get(path).header("Authorization",a)).andExpect(jsonPath("$[0].value").value("dark"));
  mvc.perform(put(path+"/theme").header("Authorization",a).contentType(MediaType.APPLICATION_JSON).content("{\"expectedVersion\":1,\"value\":\"bad\"}")).andExpect(status().isBadRequest());
  mvc.perform(put(path+"/token").header("Authorization",a).contentType(MediaType.APPLICATION_JSON).content("{\"expectedVersion\":0,\"value\":\"secret\"}")).andExpect(status().isBadRequest());
 }
}
