# ==============================================================================
# Dockerfile Production — Quantis Stock API (Java 21 + Spring Boot)
# Optimisé pour Render Free Tier (512 Mo RAM) & VPS ARM64 / x86_64
# ==============================================================================

FROM maven:3.9.9-eclipse-temurin-21-alpine AS build
WORKDIR /workspace

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S quantis && adduser -S quantis -G quantis

COPY --from=build /workspace/target/*.jar /app/app.jar
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh && chown -R quantis:quantis /app

USER quantis

ENV SPRING_PROFILES_ACTIVE=prod
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/app/docker-entrypoint.sh"]

