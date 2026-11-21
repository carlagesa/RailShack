FROM eclipse-temurin:21-jdk-alpine AS build

ARG SERVICE
WORKDIR /src
COPY libs/javakit/Kit.java ./libs/javakit/Kit.java
COPY services/${SERVICE} ./services/${SERVICE}
RUN mkdir /out && javac -d /out libs/javakit/Kit.java services/${SERVICE}/Main.java

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S -G app app
ENV PORT=8080
COPY --from=build --chown=app:app /out /app
USER app
WORKDIR /app
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-cp", "/app", "Main"]
