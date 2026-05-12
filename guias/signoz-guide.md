# 🧠 Plataforma Unificada de Observabilidad con SigNoz y ClickHouse

> *Guía práctica para desplegar y configurar SigNoz, una plataforma moderna "Todo en Uno" basada nativamente en OpenTelemetry y soportada por la base de datos columnar ClickHouse.*

---

## 🌟 Objetivo de la guía

Implementar y validar una plataforma de observabilidad de nueva generación utilizando **SigNoz**. Esta guía demuestra cómo gestionar logs masivos aprovechando el estándar **OpenTelemetry** de manera nativa y el almacenamiento analítico de alto rendimiento de **ClickHouse**.

---

## 🎯 Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Comprender la arquitectura de una plataforma unificada (Logs, Métricas y Trazas en un solo lugar).
- Entender el rol de una base de datos orientada a columnas (ClickHouse) para la ingesta y consulta masiva de logs.
- Configurar aplicaciones para emitir telemetría nativa OTLP.
- Correlacionar fallos en logs directamente con trazas distribuidas utilizando la interfaz de SigNoz.

---

## 🧭 Propósito y alcance del recurso

El propósito principal de este recurso es presentar a los estudiantes el "Estado del Arte" de la observabilidad Open Source. **SigNoz** se posiciona como una alternativa libre a gigantes comerciales como DataDog o New Relic.

A diferencia de los stacks ensamblados (como ELK o PLG), SigNoz viene preconfigurado con:
- Un colector (SigNoz OTel Collector).
- Un motor de almacenamiento veloz (ClickHouse).
- Una interfaz unificada (SigNoz Frontend).

---

## 🧩 1. Observabilidad Nativa y Almacenamiento Columnar

En el procesamiento moderno de logs y telemetría, el almacenamiento es clave. **ClickHouse** es una base de datos analítica orientada a columnas (OLAP). A diferencia de Elasticsearch (que crea pesados índices invertidos para buscar texto), ClickHouse almacena datos por columnas y comprime bloques enteros. Esto permite ingestar millones de logs por segundo usando una fracción del disco y RAM, revolucionando la manera en que la industria maneja la observabilidad masiva.

---

## ⚙️ 2. Requisitos previos

- Docker instalado y Docker Compose.
- **Fundamental:** Al menos **8 GB de RAM** libres y 4 núcleos de CPU. (ClickHouse y la interfaz de SigNoz consumen recursos considerables al operar como una plataforma completa).

---

## 📂 3. Despliegue de la Plataforma SigNoz

Debido a que SigNoz es una plataforma completa con múltiples microservicios internos (alerting, query-service, frontend, collector, clickhouse), la mejor práctica y la recomendada por la industria es utilizar el repositorio oficial de despliegue.

### 3.1 Descargar y Ejecutar el Entorno

Abra su terminal y ejecute los siguientes comandos para clonar el repositorio oficial y levantar el entorno local:

```bash
# 1. Clonar el repositorio de SigNoz
git clone -b main https://github.com/SigNoz/signoz.git

# 2. Entrar al directorio de despliegue de Docker
cd signoz/deploy/

# 3. Levantar los servicios (puede tomar un par de minutos)
docker-compose -f docker/clickhouse-setup/docker-compose.yaml up -d
```

### 3.2 Validación de los servicios

Verifique que los contenedores estén corriendo:
```bash
docker-compose -f docker/clickhouse-setup/docker-compose.yaml ps
```
Debe visualizar los contenedores `clickhouse`, `query-service`, `frontend` y `signoz-otel-collector`.

---

## 🔌 4. Emisión de logs desde aplicaciones (OTLP)

Dado que SigNoz es nativo de **OpenTelemetry**, no necesitamos agentes intermedios (como Logstash, Fluentd o Vector). Nuestra aplicación enviará los logs estructurados directamente al colector de SigNoz a través del protocolo **OTLP**.

### 4.1 Aplicaciones Quarkus

Quarkus tiene un excelente soporte para OpenTelemetry. 

**Dependencias Maven:**
```xml
<dependency>
   <groupId>io.quarkus</groupId>
   <artifactId>quarkus-opentelemetry</artifactId>
</dependency>
```

**`application.properties`**:
```properties
# Nombre de nuestro servicio que aparecerá en SigNoz
quarkus.application.name=app-inventario

# Activamos el envío de logs por OTLP
quarkus.otel.logs.enabled=true

# Apuntamos al colector de SigNoz (Puerto 4317 para gRPC)
quarkus.otel.exporter.otlp.logs.endpoint=http://localhost:4317
```

*Nota:* Si su aplicación Quarkus se está ejecutando desde su IDE (localhost) apuntará directamente al `localhost:4317` que Docker ha expuesto.

### 4.2 Otras aplicaciones Java (Logback)

Si usa Logback, se debe utilizar el *Appender* de OpenTelemetry para enviar los logs directamente en formato OTLP.

**Dependencias Maven:**
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

**`logback.xml`**:
```xml
<configuration>
  <appender name="OTEL_LOGS" class="io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender">
     <otelExporterEndpoint>http://localhost:4317</otelExporterEndpoint>
     <otelLogsExporter>
        io.opentelemetry.exporter.otlp.logs.OtlpGrpcLogRecordExporter
     </otelLogsExporter>
     <otelResourceAttributes>
        service.name=app-inventario
        deployment.environment=production
     </otelResourceAttributes>
  </appender>
  
  <root level="INFO">
     <appender-ref ref="OTEL_LOGS" />
  </root>
</configuration>
```

---

## 📊 5. Visualización en SigNoz

1. Acceda a la interfaz de SigNoz en su navegador: `http://localhost:3301`.
2. Cree una cuenta de administrador local (es requerida por seguridad en el primer inicio).
3. En el menú izquierdo, navegue a la sección **Logs**.
4. Podrá ver los logs llegar en tiempo real. 

La ventaja principal de esta interfaz es que, a diferencia de Kibana o Grafana, SigNoz está pre-construido con filtros visuales (Severity, Application, Service Name) diseñados específicamente para telemetría.

---

## 🧪 6. Actividades de profundización

- **Simular fallos y correlación:** Implemente un endpoint en la aplicación (ej. `GET /api/error`) que genere una excepción (`NullPointerException`). Ejecute el endpoint. En SigNoz, busque el log de error. Note que el log tiene asociado un `traceId`. Haga clic en el log y seleccione *Go to Trace* para ver visualmente la cascada de llamadas que causó el error. **Esta es la característica más poderosa de una plataforma unificada.**
- En la interfaz de SigNoz, navegue a *Dashboards* y observe cómo, sin configuración adicional, la plataforma ha empezado a generar métricas a partir de los logs.
- Investigue los volúmenes montados por el contenedor `clickhouse` para entender cómo se almacena la data físicamente.

---

## 🛠️ 7. Troubleshooting

**Error común:** La aplicación Java falla al iniciar indicando `Connection refused: localhost/127.0.0.1:4317`.
**Solución:** Asegúrese de que el contenedor `signoz-otel-collector` esté corriendo y que el puerto 4317 (gRPC) esté expuesto.

**Error común:** La máquina se congela o Docker se reinicia solo.
**Solución:** ClickHouse requiere recursos. Asegúrese de que su Docker Desktop (o entorno de contenedores) tenga asignados al menos 8GB de RAM y 4 núcleos virtuales en su configuración global.

---

## 📚 Referencias

- SigNoz Documentation: https://signoz.io/docs/
- Por qué ClickHouse para Logs: https://signoz.io/blog/clickhouse-vs-elasticsearch/
- Quarkus OpenTelemetry: https://quarkus.io/guides/opentelemetry

---
