# 🧠 Plataforma Unificada de Observabilidad con SigNoz y ClickHouse

> *Guía práctica para desplegar y configurar SigNoz, una plataforma moderna "Todo en Uno" basada nativamente en OpenTelemetry y soportada por la base de datos columnar ClickHouse, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.*

---

## 🌟 Objetivo de la guía

Implementar y validar una plataforma unificada de observabilidad mediante **Docker Compose**, usando **SigNoz** como solución integral que integra colector (OTel Collector), almacenamiento analítico (ClickHouse) e interfaz de exploración en un único despliegue autocontenido.

---

## 🎯 Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes internos de SigNoz y el rol de cada uno (colector, ClickHouse, Zookeeper, backend, frontend).
- Comprender las ventajas del almacenamiento columnar (ClickHouse) frente a la indexación completa (Elasticsearch) para ingestión masiva de logs.
- Configurar aplicaciones Quarkus para emitir telemetría nativa OTLP hacia SigNoz.
- Explorar y correlacionar logs con trazas distribuidas desde la interfaz de SigNoz.
- Comprender el modelo de despliegue autocontenido frente al enfoque de clonar el repositorio oficial.

---

## 🧭 Propósito y alcance del recurso

**SigNoz** se posiciona como el "estado del arte" de la observabilidad open source: una alternativa libre a plataformas comerciales como DataDog o New Relic. A diferencia de los stacks ensamblados de guías anteriores (ELK, PLG, Vector+Loki), SigNoz integra en un único despliegue:

- Un colector OTel nativo.
- Un motor analítico columnar (ClickHouse) para ingestión de alta velocidad.
- Una interfaz unificada con logs, métricas y trazas en un solo lugar.

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software y observabilidad.
- Un **entorno de laboratorio autocontenido**: no requiere clonar el repositorio de SigNoz. Todos los archivos de configuración necesarios se incluyen en la solución.
- Un **caso de estudio técnico**, que ilustra las diferencias entre un stack ensamblado y una plataforma integrada.

El alcance del recurso cubre logs, métricas y trazas distribuidas (los tres pilares de la observabilidad), aunque el énfasis educativo está en los logs.

---

## 🧩 1. Observabilidad Nativa y Almacenamiento Columnar

**ClickHouse** es una base de datos analítica orientada a columnas (OLAP). A diferencia de Elasticsearch, que crea índices invertidos para búsqueda de texto, ClickHouse almacena datos por columnas y comprime bloques enteros. Esto permite ingestar millones de logs por segundo usando una fracción del disco y RAM, revolucionando la manera en que la industria maneja la observabilidad a escala.

SigNoz es la plataforma que integra ClickHouse como motor de almacenamiento con un colector OTel nativo, aprovechando la estandarización del protocolo **OTLP** para recibir telemetría de cualquier aplicación instrumentada con OpenTelemetry.

---

## ⚙️ 2. Requisitos previos

- Docker instalado  
  https://docs.docker.com/engine/install/
- Docker Compose  
  https://docs.docker.com/compose/install/
- Al menos **8 GB de RAM** libres y 4 núcleos de CPU  
  (ClickHouse y SigNoz son los principales consumidores de recursos)
- Acceso a internet durante la primera ejecución  
  (el contenedor `init-clickhouse` descarga un binario UDF desde GitHub Releases)

---

## 📂 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
├── clickhouse/
│   ├── config.xml
│   ├── users.xml
│   ├── custom-function.xml
│   ├── cluster.xml
│   └── user_scripts/        <-- vacío; se puebla al iniciar
├── signoz/
│   └── otel-collector-opamp-config.yaml
└── otel-collector-config.yaml
```

> ℹ️ Los archivos de configuración de ClickHouse y el colector se incluyen directamente en el proyecto, eliminando la necesidad de clonar el repositorio oficial de SigNoz.

---

## 📊 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
          |
          |  OTLP (gRPC :4317)
          v
[SigNoz OTel Collector v0.144.3]
          |
     _____|_____________________
     |           |             |
     v           v             v
[ClickHouse  [ClickHouse   [ClickHouse
  signoz_logs] signoz_traces] signoz_metrics]
          |
          v
   [SigNoz v0.122.0]
   (Backend + Frontend :8888)
```

Los componentes internos del stack son:

- **Zookeeper**: coordinación de clúster de ClickHouse.
- **init-clickhouse**: descarga el binario `histogramQuantile` (UDF) necesario para ClickHouse.
- **ClickHouse**: motor de almacenamiento columnar. Aloja las bases de datos `signoz_logs`, `signoz_traces` y `signoz_metrics`.
- **signoz-telemetrystore-migrator**: aplica las migraciones de esquema sobre ClickHouse.
- **SigNoz OTel Collector**: recibe telemetría OTLP (gRPC :4317, HTTP :4318) y la escribe en ClickHouse.
- **SigNoz**: backend de consultas y frontend unificado (accesible en `:8888`).

---

## 🛠️ 5. Implementación de la arquitectura

### 5.1 docker-compose.yml

```yaml
x-common: &common
  networks:
    - signoz-net
  restart: unless-stopped
  logging:
    options:
      max-size: 50m
      max-file: "3"

x-clickhouse-defaults: &clickhouse-defaults
  <<: *common
  image: clickhouse/clickhouse-server:25.5.6
  tty: true
  depends_on:
    init-clickhouse:
      condition: service_completed_successfully
    zookeeper-1:
      condition: service_healthy
  healthcheck:
    test: ["CMD", "wget", "--spider", "-q", "0.0.0.0:8123/ping"]
    interval: 30s
    timeout: 5s
    retries: 3
  ulimits:
    nproc: 65535
    nofile:
      soft: 262144
      hard: 262144
  environment:
    - CLICKHOUSE_SKIP_USER_SETUP=1

x-db-depend: &db-depend
  <<: *common
  depends_on:
    clickhouse:
      condition: service_healthy

services:
  logs.producer:
    build:
      context: logs.producer
      dockerfile: src/main/docker/Dockerfile.compose
    networks:
      - signoz-net
    ports:
      - "8080:8080"
    environment:
      SIGNOZ_HOST: signoz-otel-collector
    depends_on:
      otel-collector:
        condition: service_healthy
    restart: unless-stopped

  init-clickhouse:
    <<: *common
    image: clickhouse/clickhouse-server:25.5.6
    container_name: signoz-init-clickhouse
    command:
      - bash
      - -c
      - |
        version="v0.0.1"
        node_os=$$(uname -s | tr '[:upper:]' '[:lower:]')
        node_arch=$$(uname -m | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)
        cd /tmp
        wget -O histogram-quantile.tar.gz "https://github.com/SigNoz/signoz/releases/download/histogram-quantile%2F$${version}/histogram-quantile_$${node_os}_$${node_arch}.tar.gz"
        tar -xvzf histogram-quantile.tar.gz
        mv histogram-quantile /var/lib/clickhouse/user_scripts/histogramQuantile
    restart: on-failure
    volumes:
      - ./clickhouse/user_scripts:/var/lib/clickhouse/user_scripts/

  zookeeper-1:
    <<: *common
    image: signoz/zookeeper:3.7.1
    container_name: signoz-zookeeper-1
    user: root
    volumes:
      - zookeeper-1:/bitnami/zookeeper
    environment:
      - ZOO_SERVER_ID=1
      - ALLOW_ANONYMOUS_LOGIN=yes
      - ZOO_AUTOPURGE_INTERVAL=1
    healthcheck:
      test: ["CMD-SHELL", "curl -s -m 2 http://localhost:8080/commands/ruok | grep error | grep null"]
      interval: 30s
      timeout: 5s
      retries: 3

  clickhouse:
    <<: *clickhouse-defaults
    container_name: signoz-clickhouse
    volumes:
      - ./clickhouse/config.xml:/etc/clickhouse-server/config.xml
      - ./clickhouse/users.xml:/etc/clickhouse-server/users.xml
      - ./clickhouse/custom-function.xml:/etc/clickhouse-server/custom-function.xml
      - ./clickhouse/cluster.xml:/etc/clickhouse-server/config.d/cluster.xml
      - ./clickhouse/user_scripts:/var/lib/clickhouse/user_scripts/
      - clickhouse:/var/lib/clickhouse/

  signoz:
    <<: *db-depend
    image: signoz/signoz:v0.122.0
    container_name: signoz
    ports:
      - "8888:8080"
    volumes:
      - sqlite:/var/lib/signoz/
    environment:
      - SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN=tcp://clickhouse:9000
      - SIGNOZ_SQLSTORE_SQLITE_PATH=/var/lib/signoz/signoz.db
      - SIGNOZ_TOKENIZER_JWT_SECRET=secret
      - SIGNOZ_ALERTMANAGER_PROVIDER=signoz
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "localhost:8080/api/v1/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  signoz-telemetrystore-migrator:
    <<: *db-depend
    image: signoz/signoz-otel-collector:v0.144.3
    container_name: signoz-telemetrystore-migrator
    environment:
      - SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_DSN=tcp://clickhouse:9000
      - SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_CLUSTER=cluster
      - SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_REPLICATION=true
      - SIGNOZ_OTEL_COLLECTOR_TIMEOUT=10m
    entrypoint: ["/bin/sh"]
    command:
      - -c
      - |
        /signoz-otel-collector migrate bootstrap &&
        /signoz-otel-collector migrate sync up &&
        /signoz-otel-collector migrate async up
    restart: on-failure

  otel-collector:
    <<: *db-depend
    image: signoz/signoz-otel-collector:v0.144.3
    container_name: signoz-otel-collector
    entrypoint: ["/bin/sh"]
    command:
      - -c
      - |
        /signoz-otel-collector migrate sync check &&
        /signoz-otel-collector --config=/etc/otel-collector-config.yaml
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    environment:
      - OTEL_RESOURCE_ATTRIBUTES=host.name=signoz-host,os.type=linux
      - LOW_CARDINAL_EXCEPTION_GROUPING=false
      - SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_DSN=tcp://clickhouse:9000
      - SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_CLUSTER=cluster
      - SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_REPLICATION=true
      - SIGNOZ_OTEL_COLLECTOR_TIMEOUT=10m
    ports:
      - "4317:4317"
      - "4318:4318"
    healthcheck:
      test: ["CMD", "bash", "-c", "echo > /dev/tcp/127.0.0.1/13133"]
      interval: 10s
      timeout: 5s
      retries: 15
      start_period: 30s

networks:
  signoz-net:
    name: signoz-net

volumes:
  clickhouse:
    name: signoz-clickhouse
  sqlite:
    name: signoz-sqlite
  zookeeper-1:
    name: signoz-zookeeper-1
```

> ℹ️ **Nota sobre el colector y opamp:** SigNoz v0.122.0 usa el protocolo opamp para distribuir configuración dinámica al colector. Para entornos de laboratorio, se omite la opción `--manager-config` para que el colector use directamente el archivo estático `otel-collector-config.yaml` y los receivers OTLP queden activos de inmediato.

> ℹ️ **Nota sobre el healthcheck del colector:** La imagen `signoz-otel-collector` no incluye `wget` ni `curl`. Se verifica la disponibilidad del puerto 13133 (health_check extension) usando `bash /dev/tcp`.

> ℹ️ **Nota sobre puertos:** SigNoz expone su interfaz en el puerto `8888` del host (mapeado al `8080` interno), para evitar conflicto con el `logs.producer` que ocupa el `8080`.

---

## ▶️ 6. Despliegue y validación

### Inicialización de los servicios

```bash
docker-compose up -d
```

> ℹ️ La primera ejecución descarga el binario `histogramQuantile` desde GitHub y aplica las migraciones de esquema en ClickHouse. Puede tardar 2–3 minutos antes de que el colector esté listo para recibir logs.

### Validación de los servicios

```bash
docker-compose ps
```

Salida esperada (referencial):

```text
NAME                       STATUS
signoz-zookeeper-1         Up (healthy)
signoz-clickhouse          Up (healthy)
signoz                     Up (healthy)
signoz-otel-collector      Up (healthy)
logs.producer-1            Up
```

---

## 🔌 7. Emisión de logs desde aplicaciones

### 7.1 Aplicaciones Quarkus

El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en **Quarkus**, usando la extensión `quarkus-opentelemetry` para exportar logs directamente al colector de SigNoz vía **OTLP/gRPC**.

- En caso de no tener una aplicación puede crear con el siguiente comando.

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest,opentelemetry' \
    -DnoCode
```

- Configure su aplicación para enviar telemetría a SigNoz. (**`application.properties`**)

```properties
quarkus.application.name=logs-producer

# OpenTelemetry: exportar logs via OTLP gRPC al colector de SigNoz
quarkus.otel.logs.enabled=true
# SIGNOZ_HOST defaults to localhost (dev/IDE); docker compose overrides to "signoz-otel-collector"
quarkus.otel.exporter.otlp.endpoint=http://${SIGNOZ_HOST:localhost}:4317
```

**Uso del logger:**

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

---

### 7.2 Otras aplicaciones Java (agente OpenTelemetry)

Para aplicaciones Java que no utilizan Quarkus, se puede usar el agente de instrumentación automática de OpenTelemetry, que intercede en Logback/Log4j2 sin modificar el código:

```bash
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.service.name=mi-servicio \
     -Dotel.exporter.otlp.endpoint=http://localhost:4317 \
     -Dotel.logs.exporter=otlp \
     -jar myapp.jar
```

---

## 📊 8. Visualización en SigNoz

1. Acceda a SigNoz en `http://localhost:8888`.
2. En el **primer acceso** cree una cuenta de administrador local (requerida por seguridad).
3. Navegue a **Logs** en el menú izquierdo para explorar los eventos recibidos.
4. Use los filtros visuales integrados: `Service Name`, `Severity`, `Timestamp`.

### Correlación logs ↔ trazas

SigNoz correlaciona automáticamente los logs generados durante peticiones HTTP con sus trazas distribuidas. Al visualizar un log con `traceId`, puede hacer clic en **"Go to Trace"** para ver la cascada completa de llamadas que originó el evento. Esta es la capacidad diferenciadora de una plataforma unificada.

---

## 🧪 9. Actividades de profundización

- **Simular fallos y correlación:** El endpoint `GET /api/error` genera intencionalmente una `NullPointerException`. Ejecútelo, localice el log de error en SigNoz y use **"Go to Trace"** para ver la traza HTTP completa asociada.
- En SigNoz, navegue a **Services** y observe cómo la plataforma construye automáticamente métricas de latencia y tasa de errores a partir de las trazas.
- Compare el uso de disco de `signoz-clickhouse` (volumen `signoz-clickhouse`) frente a los volúmenes de Elasticsearch en las guías anteriores, después de ingestar el mismo volumen de logs.
- Analice el archivo `clickhouse/config.xml` y `cluster.xml` para entender la configuración de clúster de ClickHouse para SigNoz.

---

## 🛠️ 10. Troubleshooting

**El stack tarda más de 3 minutos en arrancar.**

**Causa:** Las migraciones de esquema (`signoz-telemetrystore-migrator`) aplican múltiples DDL sobre ClickHouse. En la primera ejecución con volúmenes vacíos esto puede tardar varios minutos.

**Solución:** Sea paciente. Monitoree con `docker compose logs -f signoz-otel-collector` hasta ver `"Everything is ready. Begin running and processing data."`.

---

**El colector queda healthy pero los logs no aparecen en SigNoz.**

**Causa:** La imagen `signoz-otel-collector` no tiene `wget` ni `curl`. El healthcheck en puerto 13133 puede pasar antes de que el receiver OTLP en 4317 esté activo (el `migrate sync check` ocupa el proceso hasta que las migraciones terminan).

**Solución:** Espere a que el colector muestre `"Starting GRPC server"` y `"Starting HTTP server"` en sus logs:
```bash
docker compose logs signoz-otel-collector | grep -E "Starting GRPC|Starting HTTP"
```

---

**La máquina se congela o Docker se reinicia.**

**Causa:** ClickHouse requiere recursos considerables. En Docker Desktop, verifique que tenga asignados al menos 8 GB de RAM.

**Solución:** En Docker Desktop → Settings → Resources, aumente la memoria disponible y reinicie Docker.

---

**`init-clickhouse` falla con error de descarga.**

**Causa:** El contenedor `init-clickhouse` descarga el binario `histogramQuantile` desde GitHub Releases. Requiere acceso a internet.

**Solución:** Verifique su conexión a internet. Si está detrás de un proxy corporativo, configure las variables `http_proxy`/`https_proxy` en el entorno Docker.

---

## 📚 Referencias

- SigNoz – https://signoz.io/docs/
- SigNoz Docker Deploy – https://github.com/SigNoz/signoz/tree/main/deploy
- ClickHouse vs Elasticsearch para logs – https://signoz.io/blog/clickhouse-vs-elasticsearch/
- Quarkus OpenTelemetry – https://quarkus.io/guides/opentelemetry
- OTel Java Agent – https://opentelemetry.io/docs/zero-code/java/agent/

---

ℹ️ *Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
