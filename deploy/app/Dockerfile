FROM openjdk:8-jdk-alpine
ARG buildver=0.5.0

#RUN ./gradlew build -x test
COPY build/libs/springdemo-${buildver}.jar /app/springdemo.jar
COPY build/libs/opentelemetry-javaagent.jar /app/opentelemetry-javaagent.jar
#ENTRYPOINT ["java", "-jar", "/app/springdemo.jar"]
#ENTRYPOINT ["java", "-javaagent:/app/opentelemetry-javaagent.jar", "-Dotel.resource.attributes=service.name=demoweb", "-Dotel.exporter.otlp.endpoint=http://simplest-collector.default:4318", "-jar", "/app/springdemo.jar"]
ENTRYPOINT ["java", "-javaagent:/app/opentelemetry-javaagent.jar", "-jar", "/app/springdemo.jar"]
