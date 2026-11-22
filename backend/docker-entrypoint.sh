#!/bin/sh
set -e

# Convertit automatiquement une URL PostgreSQL standard (Neon / Render / Railway :
# postgres://user:pass@host:port/db?sslmode=require ou postgresql://...)
# en variables JDBC Spring Boot si SPRING_DATASOURCE_URL n'est pas déjà défini.
if [ -z "$SPRING_DATASOURCE_URL" ] && [ -n "$DATABASE_URL" ]; then
  case "$DATABASE_URL" in
    jdbc:*)
      export SPRING_DATASOURCE_URL="$DATABASE_URL"
      ;;
    postgres://* | postgresql://*)
      NO_SCHEME="${DATABASE_URL#postgres://}"
      NO_SCHEME="${NO_SCHEME#postgresql://}"
      case "$NO_SCHEME" in
        *@*)
          USER_PASS="${NO_SCHEME%%@*}"
          HOST_DB="${NO_SCHEME#*@}"
          export SPRING_DATASOURCE_USERNAME="${DB_USERNAME:-${USER_PASS%%:*}}"
          export SPRING_DATASOURCE_PASSWORD="${DB_PASSWORD:-${USER_PASS#*:}}"
          export SPRING_DATASOURCE_URL="jdbc:postgresql://${HOST_DB}"
          ;;
        *)
          export SPRING_DATASOURCE_URL="jdbc:postgresql://${NO_SCHEME}"
          ;;
      esac
      ;;
  esac
fi

exec java ${JAVA_OPTS:--Xms128m -Xmx280m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom} -jar /app/app.jar

