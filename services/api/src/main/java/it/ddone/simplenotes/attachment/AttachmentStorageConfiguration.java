package it.ddone.simplenotes.attachment;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.*;

/**
 * Fails closed unless an administrator configures a private bucket and an
 * S3-compatible HTTPS endpoint. No public ACL or permanent URLs.
 */
@Configuration
public class AttachmentStorageConfiguration {
    @Bean(destroyMethod = "close")
    AttachmentObjectStore attachmentObjectStore(
            @Value("${app.attachments.enabled:false}") boolean enabled,
            @Value("${app.attachments.bucket:}") String bucket,
            @Value("${app.attachments.region:eu-central-1}") String region,
            @Value("${app.attachments.endpoint:}") String endpoint) {
        if (!enabled) return new Unavailable();
        if (bucket.isBlank() || region.isBlank()) {
            throw new IllegalStateException("Attachment bucket and region required");
        }
        URI uri = endpoint.isBlank() ? null : URI.create(endpoint);
        if (uri != null &&
                (!"https".equalsIgnoreCase(uri.getScheme()) ||
                 uri.getUserInfo() != null || uri.getHost() == null ||
                 uri.getQuery() != null || uri.getFragment() != null)) {
            throw new IllegalStateException("S3 endpoint must be an HTTPS origin");
        }
        return new S3Backed(bucket, region, uri);
    }

    private static class Unavailable implements AttachmentObjectStore {
        private static ResponseStatusException unavailable() {
            return new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                "Attachment storage is not configured");
        }
        public Ticket presignPut(String key, String type, long length) {
            throw unavailable();
        }
        public Metadata inspect(String key) { throw unavailable(); }
        public byte[] readPrefix(String key, String expectedEtag, int maxBytes) {
            throw unavailable();
        }
        public void promote(String source, String destination,
                String type, String expectedEtag) {
            throw unavailable();
        }
        public String presignGet(String key) { throw unavailable(); }
        public void delete(String key) { throw unavailable(); }
    }

    private static class S3Backed implements AttachmentObjectStore {
        private final String bucket;
        private final S3Client client;
        private final S3Presigner signer;

        private S3Backed(String bucket, String region, URI endpoint) {
            this.bucket = bucket;
            var creds = DefaultCredentialsProvider.create();
            var config = S3Configuration.builder()
                .pathStyleAccessEnabled(endpoint != null).build();
            var clientBuilder = S3Client.builder()
                .region(Region.of(region)).credentialsProvider(creds)
                .serviceConfiguration(config);
            var signerBuilder = S3Presigner.builder()
                .region(Region.of(region)).credentialsProvider(creds)
                .serviceConfiguration(config);
            if (endpoint != null) {
                clientBuilder.endpointOverride(endpoint);
                signerBuilder.endpointOverride(endpoint);
            }
            client = clientBuilder.build();
            signer = signerBuilder.build();
        }

        @Override public Ticket presignPut(String key, String type, long bytes) {
            var put = PutObjectRequest.builder()
                .bucket(bucket).key(key).contentType(type)
                .contentLength(bytes).build();
            var signed = signer.presignPutObject(PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(5))
                .putObjectRequest(put).build());
            Map<String, String> headers = new LinkedHashMap<>();
            signed.signedHeaders().forEach((name, values) -> {
                if (!"host".equalsIgnoreCase(name)) {
                    headers.put(name, String.join(",", values));
                }
            });
            return new Ticket(signed.url().toExternalForm(), headers);
        }

        @Override public Metadata inspect(String key) {
            try {
                var head = client.headObject(HeadObjectRequest.builder()
                    .bucket(bucket).key(key).build());
                return new Metadata(head.contentLength(), head.contentType(), head.eTag());
            } catch (NoSuchKeyException missing) {
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Attachment upload not found");
            } catch (S3Exception error) {
                if (error.statusCode() == 404) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "Attachment upload not found");
                }
                throw error;
            }
        }

        @Override public byte[] readPrefix(String key, String expectedEtag,
                int maxBytes) {
            if (maxBytes < 1 || maxBytes > 1024 ||
                    expectedEtag == null || expectedEtag.isBlank()) {
                throw new IllegalArgumentException("Invalid attachment inspection");
            }
            try {
                return client.getObjectAsBytes(GetObjectRequest.builder()
                    .bucket(bucket).key(key).ifMatch(expectedEtag)
                    .range("bytes=0-" + (maxBytes - 1)).build()).asByteArray();
            } catch (S3Exception error) {
                if (error.statusCode() == 412 || error.statusCode() == 404) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "Attachment changed or disappeared during inspection");
                }
                throw error;
            }
        }

        @Override public void promote(String staging, String permanent,
                String type, String expectedEtag) {
            // COPY to a distinct final key prevents clients reusing a still
            // valid PUT URL to change already-confirmed content.
            String source = URLEncoder.encode(bucket + "/" + staging,
                StandardCharsets.UTF_8);
            client.copyObject(CopyObjectRequest.builder()
                .copySource(source).bucket(bucket).key(permanent)
                .copySourceIfMatch(expectedEtag)
                .contentType(type).metadataDirective(MetadataDirective.REPLACE)
                .build());
            // staging/* is removed by the bucket lifecycle policy, never
            // delete it in the DB transaction before finalization commits.
        }

        @Override public String presignGet(String key) {
            var get = GetObjectRequest.builder()
                .bucket(bucket).key(key).build();
            var signed = signer.presignGetObject(GetObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(5))
                .getObjectRequest(get).build());
            return signed.url().toExternalForm();
        }

        @Override public void delete(String key) {
            client.deleteObject(DeleteObjectRequest.builder()
                .bucket(bucket).key(key).build());
        }

        @Override public void close() {
            signer.close();
            client.close();
        }
    }
}
