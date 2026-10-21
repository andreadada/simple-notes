FROM gradle:8.14.3-jdk21 AS builder
WORKDIR /workspace
COPY settings.gradle.kts build.gradle.kts ./
COPY src ./src
RUN gradle --no-daemon bootJar

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app
COPY --from=builder /workspace/build/libs/*.jar /app/app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
