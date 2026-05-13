# 🧠 Plataforma Unificada de Observabilidad con SigNoz y ClickHouse

> *Guía práctica para desplegar y configurar SigNoz, una plataforma moderna "Todo en Uno" basada nativamente en OpenTelemetry y soportada por la base de datos columnar ClickHouse, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.*

---

## 🌟 Objetivo de la guía

Implementar y validar una plataforma unificada de observabilidad mediante **Docker Compose**, usando **SigNoz** como solución integral que integra colector (OTel Collector), almacenamiento analítico (ClickHouse) e interfaz de exploración en un único despliegue.

---

## 🎯 Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes internos de SigNoz y el rol de cada uno (colector, ClickHouse, Zookeeper, backend, frontend).
- Comprender las ventajas del almacenamiento columnar (ClickHouse) frente a la indexación completa (Elasticsearch) para ingestión masiva de logs.
- Configurar aplicaciones Quarkus para emitir telemetría nativa OTLP hacia SigNoz.
- Explorar y correlacionar logs con trazas distribuidas desde la interfaz de SigNoz.
- Comprender el patrón de *override* de Docker Compose como técnica para extender stacks de terceros sin modificar sus archivos.

---

## 🧭 Propósito y alcance del recurso

**SigNoz** se posiciona como el "estado del arte" de la observabilidad open source: una alternativa libre a plataformas comerciales como DataDog o New Relic. A diferencia de los stacks ensamblados de guías anteriores (ELK, PLG, Vector+Loki), SigNoz integra en un único despliegue:

- Un colector OTel nativo.
- Un motor analítico columnar (ClickHouse) para ingestión de alta velocidad.
- Una interfaz unificada con logs, métricas y trazas en un solo lugar.

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software y observabilidad.
- Un **entorno de laboratorio reproducible**: se clona el repositorio oficial de SigNoz a una versión fija y se extiende con un compose de *override* mínimo.
- Un **caso de estudio técnico**, que ilustra las diferencias entre un stack ensamblado y una plataforma integrada, y la técnica de composición de múltiples archivos de `docker compose`.

El alcance del recurso cubre logs, métricas y trazas distribuidas (los tres pilares de la observabilidad), aunque el énfasis educativo está en los logs.

---

## 🧩 1. Observabilidad Nativa y Almacenamiento Columnar

**ClickHouse** es una base de datos analítica orientada a columnas (OLAP). A diferencia de Elasticsearch, que crea índices invertidos para búsqueda de texto, ClickHouse almacena datos por columnas y comprime bloques enteros. Esto permite ingestar millones de logs por segundo usando una fracción del disco y RAM, revolucionando la manera en que la industria maneja la observabilidad a escala.

SigNoz es la plataforma que integra ClickHouse como motor de almacenamiento con un colector OTel nativo, aprovechando la estandarización del protocolo **OTLP** para recibir telemetría de cualquier aplicación instrumentada con OpenTelemetry.

---

## ⚙️ 2. Requisitos previos

- Docker instalado (https://docs.docker.com/engine/install/)
- Docker Compose (https://docs.docker.com/compose/install/)
- Git instalado
- Al menos **8 GB de RAM** libres.
- Conexión a Internet (el primer arranque descarga binarios UDF de ClickHouse).

---

## 📂 3. Estructura del proyecto

```bash
08-SigNoz/
├── docker-compose.yml          <-- Override mínimo (otel-collector + logs.producer)
├── logs.producer/
│   ├── src/
│   └── pom.xml
└── signoz/                     <-- Repositorio oficial clonado (no se edita)
    └── deploy/docker/
        ├── docker-compose.yaml
        └── otel-collector-config.yaml
```

El directorio `signoz/` se obtiene clonando el repositorio oficial a una versión fija. **No se edita ningún archivo** de ese directorio: toda la personalización vive en el `docker-compose.yml` de *override*.

---

## 📊 4. Arquitectura de la solución

```text
[Aplicación Quarkus / logs.producer]
         |
    (OTLP gRPC :4317)
         v
 [SigNoz OTel Collector]
         |
   (Exportador nativo)
         v
     [ClickHouse]
         |
         v
  [SigNoz Backend] ---> [SigNoz UI :8080]
```

Los componentes internos del stack SigNoz son:

| Contenedor | Rol |
|---|---|
| `signoz-otel-collector` | Recibe telemetría OTLP (gRPC :4317, HTTP :4318) |
| `signoz-clickhouse` | Almacenamiento columnar OLAP para logs, trazas y métricas |
| `signoz-zookeeper-1` | Coordinación de clúster ClickHouse |
| `signoz` | Backend API + Frontend (UI web en :8080) |

---

## 🛠️ 5. Implementación de la arquitectura

### 5.1 Paso 1: Descargar el repositorio de SigNoz

El repositorio oficial de SigNoz no se incluye en este repositorio (167 MB, más de 7000 archivos). Desde el directorio `08-SigNoz/`, ejecute el script de setup incluido:

```bash
./setup.sh
```

El script equivale a:

```bash
git clone --depth 1 --branch v0.122.0 https://github.com/SigNoz/signoz.git
```

> ℹ️ **Nota:** `--depth 1` descarga solo el último commit (sin historia), reduciendo el tamaño. `--branch v0.122.0` fija la versión para reproducibilidad. El directorio `signoz/` está en `.gitignore` y no se versiona.

---

### 5.2 Paso 2: El override `docker-compose.yml`

El archivo de *override* que acompaña esta guía tiene dos responsabilidades:

1. **Corregir el comando del colector**: el compose oficial inicia el colector con `--manager-config`, que activa el protocolo opAMP para configuración dinámica desde SigNoz. En un entorno de laboratorio esto impide que los receptores OTLP (puerto 4317) se activen hasta que el usuario cree una cuenta y un agente vinculado. El override elimina ese flag para que los receptores arranquen con la configuración estática.

2. **Agregar la aplicación de demostración**: el servicio `logs.producer` se une a la red `signoz-net` que crea el compose oficial.

```yaml
services:
  # Override: remove --manager-config so OTLP receivers (port 4317) activate without
  # needing a live SigNoz account / opamp connection.
  otel-collector:
    command:
      - -c
      - |
        /signoz-otel-collector migrate sync check &&
        /signoz-otel-collector --config=/etc/otel-collector-config.yaml

  logs.producer:
    build:
      context: ../../../logs.producer
      dockerfile: src/main/docker/Dockerfile.compose
    ports:
      - "8090:8080"        # 8080 ya lo usa el frontend de SigNoz
    environment:
      SIGNOZ_HOST: signoz-otel-collector
    networks:
      - signoz-net
    restart: unless-stopped
```

> ℹ️ **Nota:** El `context` del build usa una ruta relativa desde el directorio del primer `-f` (`signoz/deploy/docker/`), por eso el path `../../../logs.producer` apunta al directorio correcto.

---

### 5.3 Configuración de la aplicación (`application.properties`)

```properties
quarkus.application.name=logs-producer

# OpenTelemetry: exportar logs via OTLP gRPC al colector de SigNoz
quarkus.otel.logs.enabled=true
# SIGNOZ_HOST defaults to localhost (dev/IDE); docker compose overrides to "signoz-otel-collector"
quarkus.otel.exporter.otlp.endpoint=http://${SIGNOZ_HOST:localhost}:4317
```

La extensión `quarkus-opentelemetry` envía logs, trazas y métricas automáticamente en formato OTLP. No se requiere ningún agente externo ni appender adicional.

---

## ▶️ 6. Despliegue y validación

### 6.1 Levantar el stack

Desde el directorio `08-SigNoz/`, ejecute:

```bash
docker compose \
  -f signoz/deploy/docker/docker-compose.yaml \
  -f docker-compose.yml \
  up -d --build
```

Docker Compose fusiona los dos archivos: el oficial define la infraestructura (ClickHouse, Zookeeper, colector, backend/frontend) y el override corrige el comando del colector y agrega `logs.producer`.

Verifique que todos los contenedores están activos y saludables:

```bash
docker compose \
  -f signoz/deploy/docker/docker-compose.yaml \
  -f docker-compose.yml \
  ps
```

El colector puede tardar hasta 60 segundos en completar la migración de esquemas de ClickHouse en el primer arranque.

### 6.2 Detener el stack

```bash
docker compose \
  -f signoz/deploy/docker/docker-compose.yaml \
  -f docker-compose.yml \
  down
```

> ⚠️ **Nota:** Para eliminar también los volúmenes (ClickHouse, Zookeeper, SQLite), agregue `--volumes`. Esto borra todos los datos almacenados.

---

## 🔌 7. Emisión de logs desde aplicaciones

### 7.1 Aplicaciones Quarkus

- En caso de no tener una aplicación, créela con:

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest,opentelemetry' \
    -DnoCode
```

- Configure el exportador OTLP en `application.properties`:

```properties
quarkus.application.name=logs-producer
quarkus.otel.logs.enabled=true
quarkus.otel.exporter.otlp.endpoint=http://${SIGNOZ_HOST:localhost}:4317
```

**Uso del logger:**

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

> ℹ️ **Nota:** A diferencia de otras guías, aquí no se escribe en archivos ni se configura un socket. El OTel SDK envía los logs directamente al colector por red en formato OTLP. Las trazas HTTP se correlacionan automáticamente con los logs mediante `trace_id` y `span_id`.

---

## 📊 8. Visualización en SigNoz

Acceda a SigNoz en `http://localhost:8080`.

> ℹ️ **Primer acceso:** SigNoz le pedirá crear una cuenta de administrador (correo y contraseña). Esto es local, no requiere ningún servicio externo.

### 8.1 Explorar logs

Navegue a **Logs → Logs Explorer** en el menú lateral.

**Filtros útiles:**

```
service.name = logs-producer
```

```
severity_text = ERROR
```

```
body contains NullPointerException
```

### 8.2 Correlación con trazas

En la vista de detalle de un log, el campo `trace_id` actúa como enlace directo a la traza distribuida correspondiente. Esto permite ver el contexto completo de una petición HTTP (latencia, spans) desde un mensaje de log.

### 8.3 Generar tráfico de prueba

La aplicación expone los siguientes endpoints:

| Método | Path | Descripción |
|--------|------|-------------|
| `POST` | `/logs` | Emite un log al nivel y con el mensaje indicados |
| `GET`  | `/api/error` | Genera una `NullPointerException` intencional |

```bash
# Emitir logs de prueba
curl -X POST http://localhost:8090/logs \
  -H "Content-Type: application/json" \
  -d '{"level":"INFO","message":"Hola desde el laboratorio SigNoz"}'

# Generar un error
curl http://localhost:8090/api/error
```

---

## 🧪 9. Actividades de profundización

- **Correlación logs–trazas:** Genere errores con `GET /api/error` y siga el enlace `trace_id` desde el log hasta la traza completa en SigNoz Traces.
- **Comparar modelos de indexación:** Contraste el enfoque columnar de ClickHouse (sin índice de texto completo) con la indexación invertida de Elasticsearch. ¿Cómo afecta esto al costo de almacenamiento y a la velocidad de ingesta?
- **Analizar el override de Docker Compose:** Inspeccione el `docker-compose.yml` de override y explique por qué basta cambiar `command` sin copiar toda la definición del servicio.
- **Explorar el protocolo opAMP:** Investigue qué es el protocolo opAMP (*Open Agent Management Protocol*) y por qué SigNoz lo usa para la configuración dinámica del colector en producción.
- **Desplegar una segunda aplicación:** Agregue un segundo servicio al override, asígnele un `quarkus.application.name` diferente y filtre por él en el Logs Explorer.

### Preguntas de verificación

1. ClickHouse almacena datos en formato columnar (OLAP), mientras que Elasticsearch usa índices invertidos orientados a búsqueda de texto. Explique por qué el almacenamiento columnar ofrece ventajas de compresión y velocidad de ingesta para logs de alta frecuencia, y qué tipo de consultas se vuelven más eficientes con cada motor.
2. El override de Docker Compose de esta guía solo redefine el campo `command` del servicio `otel-collector` sin duplicar el resto de su definición. Analice el mecanismo de fusión de archivos que usa Docker Compose para entender cómo se combinan las claves del compose oficial con las del override, y qué ocurriría si se omitiera el override al levantar el stack.
3. El protocolo opAMP (*Open Agent Management Protocol*) permite la configuración dinámica del OTel Collector desde SigNoz sin reiniciar el contenedor. Evalúe las implicaciones de seguridad y operativas de habilitar opAMP en producción frente al enfoque de configuración estática usado en esta guía de laboratorio.

---

## 🛠️ 10. Troubleshooting

**El puerto 4317 no responde (conexión rechazada desde `logs.producer`).**

**Causa:** El colector arrancó con `--manager-config` (si se usa el compose oficial sin el override) y los receptores OTLP esperan que el servidor opAMP les entregue la configuración de forma dinámica.

**Solución:** Asegúrese de lanzar **siempre** los dos compose con `-f signoz/deploy/docker/docker-compose.yaml -f docker-compose.yml`. El override elimina `--manager-config` para que los receptores usen la configuración estática.

---

**El colector tarda en arrancar — `logs.producer` reporta errores de conexión al inicio.**

**Causa:** El colector ejecuta migraciones de esquema en ClickHouse antes de abrir el puerto 4317. En el primer arranque puede tardar hasta 60 segundos.

**Solución:** Espere hasta que `docker compose ps` muestre el colector `Up` (sin estado de salud explícito). La aplicación reintentará la conexión automáticamente gracias a `restart: unless-stopped`.

---

**El primer arranque tarda mucho tiempo.**

**Causa:** `init-clickhouse` descarga un binario de funciones UDF (histogramQuantile) desde GitHub al primer inicio.

**Solución:** Espere a que el contenedor `signoz-init-clickhouse` finalice (`Exited (0)`). Este paso solo ocurre la primera vez; los reinicios posteriores son rápidos porque los volúmenes persisten los datos.

---

**`docker compose up` falla con "port is already allocated" en el puerto 8080.**

**Causa:** Hay otro servicio (por ejemplo, otra guía del laboratorio) usando el puerto 8080 en el host.

**Solución:** Detenga el servicio conflictivo antes de levantar este stack. El frontend de SigNoz necesita el puerto 8080 en el host.

---

## 📚 Referencias

- SigNoz Documentation: https://signoz.io/docs/
- SigNoz GitHub: https://github.com/SigNoz/signoz
- ClickHouse Documentation: https://clickhouse.com/docs/
- OpenTelemetry Protocol (OTLP): https://opentelemetry.io/docs/specs/otlp/
- opAMP (Open Agent Management Protocol): https://opentelemetry.io/docs/collector/management/
- Quarkus OpenTelemetry Guide: https://quarkus.io/guides/opentelemetry

---

ℹ️ *Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
