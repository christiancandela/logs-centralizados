# 🧠 Centralización de Logs con OpenTelemetry (LGTM)

> *Guía práctica para implementar una solución básica de centralización de logs utilizando Docker Compose y OpenTelemetry, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.*

---

## 🌟 Objetivo de la guía

Implementar y validar una arquitectura básica de centralización de logs mediante **Docker Compose**, usando un stack basado en **OpenTelemetry** para la recolección de logs y **Grafana** como herramienta de exploración.

---

## ✅ Resultados esperados

Al finalizar esta guía, el estudiante será capaz de:

- Desplegar un entorno local de observabilidad basado en `grafana/otel-lgtm`.
- Enviar logs desde una aplicación Quarkus mediante OTLP.
- Enviar logs desde aplicaciones Java usando Logback.
- Explorar logs centralizados desde Grafana.

---

## 🧭 Propósito y alcance del recurso

Este recurso tiene un propósito formativo y busca materializar, en un entorno reproducible, los conceptos de recolección, transporte, agregación y visualización de logs como parte de la observabilidad de sistemas.

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un **entorno de laboratorio reproducible**, que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un **caso de estudio técnico**, que ilustra la integración entre aplicaciones Java y una plataforma de observabilidad.

El alcance del recurso se limita a un entorno local con Docker Compose, adecuado para prácticas académicas y laboratorios.

---

## 🧩 1. Observabilidad y centralización de logs con OpenTelemetry

En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de las señales externas que este produce durante su ejecución. Los **logs** constituyen una fuente primaria de información debido a su riqueza semántica y contextual.

La **centralización de logs** mitiga la dispersión inherente a los sistemas distribuidos, consolidando los registros generados por múltiples componentes en un repositorio común que facilita su análisis, correlación temporal y visualización.

OpenTelemetry define un conjunto de APIs y SDKs que permiten capturar y exportar señales de observabilidad (logs, métricas y trazas) hacia un backend común mediante el protocolo OTLP.  
En esta guía el énfasis está en la **centralización de logs**, usando Grafana como punto de análisis.

---

## 📦 2. Requisitos previos

- Docker instalado  
  https://docs.docker.com/engine/install/
- Docker Compose  
  https://docs.docker.com/compose/install/
- Al menos **8 GB de RAM** libres

---

## 🗂️ 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer
│   ├── src/
│   └── pom.xml
└── .env (opcional)
```

---

## 🧱 4. Arquitectura del recurso

```text
[Aplicaciones Java / Quarkus]
          |
          |  OTLP (gRPC / HTTP)
          v
[grafana/otel-lgtm]
          |
          v
      [Grafana]
```

La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- **Open Telemetry** (Colector/Agregador de logs)
- **Prometheus** (Metrics Database)
- **Loki** (Logs Database)
- **Tempo** (Trace Database)
- **Grafana** (Visualización)

El uso de **Docker Compose** permite describir y desplegar la arquitectura como código, garantizando la **portabilidad, reproducibilidad y facilidad de experimentación** del entorno, características fundamentales en un contexto formativo.

---

## 🛠️ 5. Implementación de la arquitectura conceptual con OpenTelemetry

### 5.1 docker-compose.yml

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

## ▶️ 6. Despliegue y validación

### Inicialización de los servicios

El despliegue del entorno se realiza mediante un único comando, el cual levanta de forma coordinada todos los componentes definidos en el archivo `docker-compose.yml`.

```bash
docker-compose up -d
```

---

### Validación de los servicios

La validación del entorno permite comprobar que el contenedor asociado a OpenTelemetry se encuentre en ejecución y disponible.

```bash
docker-compose ps
```

Salida esperada:

```text
NAME                STATUS              PORTS
grafana_otel_lgtm   Up                  3000/tcp, 4317/tcp, 4318/tcp
```

---

### Persistencia y configuración del entorno

Para fines formativos el despliegue es suficiente tal como está.  
En escenarios productivos se recomienda desacoplar los componentes y definir almacenamiento persistente.

---

## 🔌 7. Emisión de logs desde aplicaciones

### 7.1 Aplicaciones Quarkus

El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en **Quarkus**, utilizando **logging estructurado en formato JSON**.  
Esta aproximación favorece la **normalización semántica de los eventos**, facilitando su procesamiento, correlación y análisis posterior dentro de la plataforma de centralización de logs.

- En caso de no tener una aplicación puede crear con el siguiente comando.

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.19.1:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest' \
    -DnoCode
```

- Adicionar la siguiente dependencia a su proyecto.

```xml
<dependency>
   <groupId>io.quarkus</groupId>
   <artifactId>quarkus-opentelemetry</artifactId>
</dependency>
```

- Configure su aplicación para que los logs sean enviados a OpenTelemetry. (**`application.properties`**)

```properties
quarkus.application.name=myservice
quarkus.otel.logs.enabled=true
quarkus.otel.exporter.otlp.logs.endpoint=http://localhost:4317
```

**Uso del logger:**

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

---

### 7.2 Otras aplicaciones Java (Logback)

Para otras aplicaciones Java que no utilizan Quarkus, el recurso presenta un ejemplo basado en **OpenTelemetry**, empleando un *encoder* compatible con OpenTelemetry para la generación de logs estructurados en formato JSON.

Este enfoque permite ilustrar cómo aplicaciones Java tradicionales pueden integrarse a una arquitectura de centralización de logs, resaltando la importancia de la estructuración y consistencia de los eventos generados.


```xml
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
<dependency>
   <groupId>io.opentelemetry</groupId>
   <artifactId>opentelemetry-exporter-otlp</artifactId>
   <version>1.30.0</version>
</dependency>
<dependency>
   <groupId>io.opentelemetry.instrumentation</groupId>
   <artifactId>opentelemetry-logback-appender-1.0</artifactId>
   <version>1.30.0-alpha</version>
</dependency>
```

Configuración `logback.xml`:

```xml
<configuration>
  <appender name="OTEL_LOGS" class="io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender">
     <otelExporterEndpoint>http://localhost:4317</otelExporterEndpoint>
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
</configuration>
```

> ℹ️ Alternativamente, puede utilizarse el agente de OpenTelemetry.

---

## 🔎 8. Exploración y análisis en Grafana

Una vez centralizados, los logs pueden ser explorados mediante Grafana, permitiendo:

- Búsqueda textual y estructurada.
- Filtros temporales.
- Identificación de patrones y anomalías.

Estas capacidades resultan especialmente relevantes en contextos educativos para ilustrar procesos de diagnóstico y análisis de fallos.

Acceder a Grafana:

```text
http://localhost:3000
```

Ruta sugerida:

- **Drilldown → Logs**

---

## 🧪 9. Actividades de profundización

- **Simular fallos y rastrear su origen:** Implemente un endpoint en la aplicación productora (ej. `GET /api/error`) que genere intencionalmente una excepción (como `NullPointerException`). Ejecute el endpoint y utilice Grafana para buscar el error y visualizar los atributos correlacionados (como el `traceId` inyectado automáticamente por OpenTelemetry).
- Comparar OpenTelemetry, Fluentd y Logstash como componentes de procesamiento.
- Modificar filtros para enriquecer eventos.
- Simular múltiples productores de logs.
- Analizar implicaciones del uso de UDP.

---

## 📚 Referencias

- OpenTelemetry: https://opentelemetry.io/docs/
- Prometheus: https://github.com/prometheus/prometheus
- Tempo: https://github.com/grafana/tempo/
- Loki: https://github.com/grafana/loki/
- Grafana: https://github.com/grafana/grafana
- Blog: *An OpenTelemetry backend in a Docker image: Introducing grafana/otel-lgtm*  
  https://grafana.com/blog/2024/03/13/an-opentelemetry-backend-in-a-docker-image-introducing-grafana/otel-lgtm/
