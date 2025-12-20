# **Centralización de Logs - ELK Stack**

---

## **Objetivo**
Configurar una arquitectura centralizada de logs usando **Docker Compose** con los siguientes componentes:
- **Open Telemetry** (Colector/Agregador de logs)
- **Prometheus** (Metrics Database)
- **Loki** (Logs Database)
- **Tempo** (Trace Database)
- **Grafana** (Visualización)

---

## **1. Requisitos Previos**
✅ Docker instalado ([Guía de instalación](https://docs.docker.com/engine/install/))  
✅ Docker Compose ([Guía](https://docs.docker.com/compose/install/))  
✅ 4 GB de RAM mínimo (recomendado para Elasticsearch)

---

## **2. Estructura del Proyecto**
Crea la siguiente estructura de archivos:
```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer
│   ├── src/
│   └── pom.xml
└── .env (opcional, para variables)
```

---

## **3. Configuración de Contenedores**

### **a. `docker-compose.yml`**
```yaml
services:
   grafana_otel_lgtm:
      image: docker.io/grafana/otel-lgtm:0.11.0
      container_name: grafana_otel_lgtm
      ports:
         - "3000:3000"
         - "4317:4317"
         - "4318:4318"
```

---

## **4. Despliegue**

### **Paso 1: Iniciar los servicios**
```bash
docker-compose up -d
```

### **Paso 2: Verificar contenedores**
```bash
docker-compose ps
```
Salida esperada:
```
NAME                STATUS              PORTS
grafana_otel_lgtm   Up                  3000/tcp, 4317/tcp, 4318/tcp
```

---

## **5. Configuración de Aplicaciones**

Cree una aplicación java que envíe sus logs a **fluentd**

### **a. Para aplicaciones Quarkus**
En el caso de aplicaciones quarkus deberá adicionar:

- Crear su aplicación 

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.19.1:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest' \
    -DnoCode
```

- Adicionar la siguiente dependencia en el archivo **`logs.producer/pom.xml`**.

```xml
<dependency>
   <groupId>io.quarkus</groupId>
   <artifactId>quarkus-logging-json</artifactId>
</dependency>
```

- Configure la aplicación en el **`logs.producer/src/main/resources/application.properties`** para que los logs sean enviados a logstash

```properties
quarkus.log.console.json=false
quarkus.log.syslog.enable=true
quarkus.log.syslog.endpoint=localhost:5140
quarkus.log.syslog.protocol=udp
quarkus.log.syslog.app-name=logs.producer
quarkus.log.syslog.hostname=${HOSTNAME}
```

- Para el registro de logs en su aplicación haga uso de la clase **`org.jboss.logging.Logger`** que puede ser inicializada o inyectada.

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

o

```java
@Inject
private final Logger log;
```

o

```java
private final Logger log;

@Inject
public MiClase(Logger log) {
   this.log = log;
}
```

o

```java
private final Logger log;

public MiClase(Logger log) {
   this.log = log;
}
```

> ℹ️ En quarkus es posible omitir la anotación **`@Inject`**

### **b. Para otras aplicaciones java**
Se puede hacer uso de las siguientes librerías para el envío de los logs.

```xml

<!-- API y SDK de OpenTelemetry -->
<dependency>
   <groupId>io.opentelemetry</groupId>
   <artifactId>opentelemetry-api</artifactId>
   <version>1.30.0</version>
</dependency>
<dependency>
   <groupId>io.opentelemetry</groupId>
   <artifactId>opentelemetry-sdk</artifactId>
   <version>1.30.0</version>
</dependency>
<!-- Exportador a OTLP (para enviar al Collector) -->
<dependency>
   <groupId>io.opentelemetry</groupId>
   <artifactId>opentelemetry-exporter-otlp</artifactId>
   <version>1.30.0</version>
</dependency>
<!-- Bridge para logs de SLF4J (Logback/Log4j) -->
<dependency>
   <groupId>io.opentelemetry.instrumentation</groupId>
   <artifactId>opentelemetry-logback-appender-1.0</artifactId>
   <version>1.30.0-alpha</version>
</dependency>

```

Configura `logback.xml` para enviar logs a Logstash:
```xml
<appender name="OTEL_LOGS" class="io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender">
   <!-- Endpoint del OpenTelemetry Collector -->
   <otelExporterEndpoint>http://localhost:4317</otelExporterEndpoint> <!-- gRPC -->
   <otelLogsExporter>
      io.opentelemetry.exporter.otlp.logs.OtlpGrpcLogRecordExporter
   </otelLogsExporter>
   <otelResourceAttributes>
      service.name=My-Java-App
      deployment.environment=production
   </otelResourceAttributes>
</appender>

<root level="INFO">
<appender-ref ref="OTEL_LOGS" />
</root>
```
> ℹ️ Otra opción para el envío de los logs es el uso del agente de OpenTelemetry.

---

## **6. Visualización en Grafana**
1. Accede a Kibana:
   ```bash
   http://localhost:3000
   ```  
2. Ingrese a **Drilldown > Logs**

---

## **7. Escalabilidad**
### **Para entornos productivos:**
- En entornos productivos es necesario desacoplar los componentes (OpenTelemetry collector, Prometheus, Tempo, Loki y Grafana) con el fin de maximizar su escalabilidad y adaptabilidad a las necesidades propias de cada proyecto.
- Añade autenticación para acceso a las diferentes herramientas.

---

## **8. Comandos Útiles**
| Comando                      | Descripción                  |
|------------------------------|------------------------------|
| `docker-compose logs -f`     | Ver logs en tiempo real      |
| `docker-compose down -v`     | Detener y eliminar volúmenes |
| `curl http://localhost:3000` | Verificar Grafana            |

---

## **Referencias**
- [OpenTelemetry collector](https://opentelemetry.io/docs/collector/)
- [Prometheus](https://github.com/prometheus/prometheus)
- [Tempo](https://github.com/grafana/tempo/)
- [Loki](https://github.com/grafana/loki/)
- [Grafana](https://github.com/grafana/grafana)
- [Blog - An OpenTelemetry backend in a Docker image: Introducing grafana/otel-lgtm](https://grafana.com/blog/2024/03/13/an-opentelemetry-backend-in-a-docker-image-introducing-grafana/otel-lgtm/)
---

