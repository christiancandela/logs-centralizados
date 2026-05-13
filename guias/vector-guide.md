# 🧠 Pipeline de Observabilidad con Vector, Loki y Grafana

> *Guía práctica para implementar una solución de centralización de logs de alto rendimiento utilizando Vector como enrutador y transformador, conectado a Loki y Grafana, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.*

---

## 🌟 Objetivo de la guía

Implementar y validar una arquitectura moderna de enrutamiento y centralización de logs mediante **Docker Compose**, usando **Vector** (escrito en Rust) como recolector y transformador ligero, **Loki** para el almacenamiento eficiente por etiquetas, y **Grafana** para la exploración y análisis.

---

## 🎯 Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de un pipeline de observabilidad basado en Vector, Loki y Grafana.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica de alto rendimiento.
- Configurar Vector con el modelo *Source → Transform → Sink* y el lenguaje **VRL** (Vector Remap Language).
- Configurar aplicaciones Java para emitir logs estructurados en JSON vía TCP hacia Vector.
- Explorar y consultar logs centralizados desde Grafana usando **LogQL**.
- Comparar el enfoque Vector frente a alternativas como Logstash o Fluentd en términos de rendimiento y consumo de recursos.

---

## 🧭 Propósito y alcance del recurso

Esta guía representa el estado del arte en enrutamiento y procesamiento de telemetría. **Vector** está diseñado para ser significativamente más eficiente que alternativas basadas en JVM (Logstash) o Ruby (Fluentd), al ser un ejecutable nativo compilado en Rust.

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un **entorno de laboratorio reproducible**, que permite experimentar con flujos reales de generación, transformación y análisis de logs.
- Un **caso de estudio técnico**, que ilustra el modelo de pipeline declarativo de Vector y el lenguaje VRL para la transformación de eventos.

El alcance del recurso se limita a la centralización y visualización de logs vía TCP JSON. Vector soporta docenas de fuentes y destinos adicionales (archivos, Docker, Kafka, S3, Elasticsearch, etc.).

---

## 🧩 1. Observabilidad y rendimiento con Vector

En arquitecturas donde el volumen de logs es masivo, el componente de recolección y procesamiento puede convertirse en el cuello de botella. **Vector** soluciona esto al ser un ejecutable nativo (Rust) que:

- Consume una fracción de los recursos de CPU y RAM frente a Logstash o Fluentd.
- Permite transformar eventos **en memoria** sin necesidad de plugins externos ni dependencias de runtime.
- Soporta múltiples fuentes (*sources*) y destinos (*sinks*) mediante un modelo de pipeline declarativo.
- Incluye **VRL (Vector Remap Language)**, un lenguaje de transformación seguro y tipado, específicamente diseñado para manipular eventos de observabilidad.

---

## ⚙️ 2. Requisitos previos

- Docker instalado  
  https://docs.docker.com/engine/install/
- Docker Compose  
  https://docs.docker.com/compose/install/
- Al menos **8 GB de RAM** libres (Vector es muy ligero; Loki y Grafana son los principales consumidores)

---

## 📂 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
├── vector/
│   └── vector.toml
└── grafana/
    └── provisioning/
        └── datasources/
            └── loki.yaml
```

---

## 📊 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
         |
     (TCP JSON :4560)
         v
      [Vector 0.38]
      Source → Transform (VRL) → Sink
         |
     (HTTP API push)
         v
       [Loki 3.0] ──→ [Grafana 13.0]
```

La arquitectura implementada se fundamenta en cuatro componentes:

- **Vector**: recolector y transformador de logs. Recibe eventos JSON vía TCP, aplica transformaciones con VRL y los envía a Loki.
- **VRL (Vector Remap Language)**: lenguaje declarativo para manipular eventos dentro del pipeline (extracción de campos, enriquecimiento, censura de datos).
- **Loki**: motor de almacenamiento ligero que indexa solo etiquetas (*labels*), no el contenido textual.
- **Grafana**: capa de visualización y exploración mediante **LogQL**.

---

## 🛠️ 5. Implementación de la arquitectura conceptual

### 5.1 docker-compose.yml

```yaml
services:
  logs.producer:
    build:
      context: logs.producer
      dockerfile: src/main/docker/Dockerfile.compose
    ports:
      - "8080:8080"
    environment:
      VECTOR_HOST: vector
    depends_on:
      vector:
        condition: service_healthy

  vector:
    image: timberio/vector:0.38.0-alpine
    container_name: vector
    command: ["--config", "/etc/vector/vector.toml"]
    volumes:
      - source: ./vector/vector.toml
        target: /etc/vector/vector.toml
        type: bind
    ports:
      - "4560:4560"
      - "8686:8686"
    healthcheck:
      test: ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:8686/health || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 10s
    depends_on:
      loki:
        condition: service_healthy

  loki:
    image: grafana/loki:3.0.0
    container_name: loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:3100/ready || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 15s

  grafana:
    image: grafana/grafana:13.0.1
    container_name: grafana
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
    ports:
      - "3000:3000"
    volumes:
      - source: ./grafana/provisioning
        target: /etc/grafana/provisioning
        type: bind
    depends_on:
      loki:
        condition: service_healthy
```

> ℹ️ **Nota sobre el comando de Vector:** La imagen `timberio/vector` carga por defecto `/etc/vector/vector.yaml`. Al usar un archivo `.toml`, es necesario especificarlo explícitamente con `command: ["--config", "/etc/vector/vector.toml"]`.

> ℹ️ **Nota sobre el healthcheck de Vector:** La imagen Alpine de Vector usa busybox `wget`, que no soporta la opción `--spider`. Se usa `-O /dev/null` en su lugar. Además, se usa `127.0.0.1` en vez de `localhost` para evitar inconsistencias con la resolución de la interfaz de loopback en busybox.

---

### 5.2 Configuración del pipeline Vector (`vector/vector.toml`)

```toml
# Habilita la API interna de Vector (requerida para el healthcheck)
[api]
enabled = true
address = "0.0.0.0:8686"

# 1. ORIGEN: recibe logs JSON delimitados por newline via TCP
[sources.java_app]
type = "socket"
address = "0.0.0.0:4560"
mode = "tcp"
framing.method = "newline_delimited"
decoding.codec = "json"

# 2. TRANSFORMACIÓN: extrae el nivel de log desde la clave plana "log.level" (formato ECS)
[transforms.enrich]
type = "remap"
inputs = ["java_app"]
source = '''
.level = ."log.level" || "unknown"
'''

# 3. DESTINO: envía los eventos enriquecidos a Loki
[sinks.loki_out]
type = "loki"
inputs = ["enrich"]
endpoint = "http://loki:3100"
encoding.codec = "json"

  [sinks.loki_out.labels]
  job = "vector_app_logs"
  level = "{{ level }}"
```

> ℹ️ **Nota sobre VRL y claves con punto:** En el formato ECS, el nivel de log se serializa como la clave plana `"log.level"` (no como objeto anidado). En VRL, para acceder a esta clave sin que sea interpretada como ruta anidada, se usa la sintaxis `."log.level"` (entre comillas). El operador `||` realiza null-coalescing: si el campo no existe o es nulo, usa el valor por defecto `"unknown"`. No se usa el operador `??` (que es para error-coalescing, no para null).

---

### 5.3 Aprovisionamiento de Grafana (`grafana/provisioning/datasources/loki.yaml`)

```yaml
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
```

---

## ▶️ 6. Despliegue y validación

### Inicialización de los servicios

```bash
docker-compose up -d
```

### Validación de los servicios

```bash
docker-compose ps
```

Salida esperada (referencial):

```text
NAME                STATUS
loki                Up (healthy)
vector              Up (healthy)
grafana             Up
logs.producer-1     Up
```

---

## 🔌 7. Emisión de logs desde aplicaciones

### 7.1 Aplicaciones Quarkus

El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en **Quarkus**, usando el socket handler JSON para enviar logs estructurados directamente al socket TCP de Vector.

- En caso de no tener una aplicación puede crear con el siguiente comando.

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest,logging-json' \
    -DnoCode
```

- Configure su aplicación para que los logs sean enviados a Vector. (**`application.properties`**)

```properties
quarkus.log.console.json=false

# Enviar logs estructurados en JSON via TCP a Vector
quarkus.log.socket.enable=true
quarkus.log.socket.json=true
# VECTOR_HOST defaults to localhost (dev/IDE); docker compose overrides to "vector"
quarkus.log.socket.endpoint=${VECTOR_HOST:localhost}:4560
quarkus.log.socket.json.exception-output-type=formatted
quarkus.log.socket.json.log-format=ECS
```

**Uso del logger:**

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

---

### 7.2 Otras aplicaciones Java (Logback)

Para aplicaciones Java que no utilizan Quarkus, se puede usar el `LogstashTcpSocketAppender`, 100% compatible con la entrada TCP de Vector.

```xml
<dependency>
  <groupId>net.logstash.logback</groupId>
  <artifactId>logstash-logback-encoder</artifactId>
  <version>8.1</version>
</dependency>
```

`logback.xml`:

```xml
<configuration>
  <appender name="VECTOR" class="net.logstash.logback.appender.LogstashTcpSocketAppender">
    <destination>vector:4560</destination>
    <encoder class="net.logstash.logback.encoder.LogstashEncoder" />
  </appender>

  <root level="INFO">
    <appender-ref ref="VECTOR" />
  </root>
</configuration>
```

---

## 📊 8. Visualización en Grafana

Acceda a Grafana en `http://localhost:3000`. La fuente de datos Loki ya está preconfigurada.

Navegue a **Explore** y seleccione **Loki** como fuente de datos.

**Consultas LogQL de ejemplo:**

Todos los logs del pipeline Vector:
```logql
{job="vector_app_logs"}
```

Filtrar por nivel:
```logql
{job="vector_app_logs", level="ERROR"}
```

Buscar excepciones por contenido:
```logql
{job="vector_app_logs"} |= "NullPointerException"
```

Parsear campos ECS y mostrar solo el mensaje:
```logql
{job="vector_app_logs"} | json | line_format "{{.message}}"
```

---

## 🧪 9. Actividades de profundización

- **Simular fallos y rastrear su origen:** El endpoint `GET /api/error` genera intencionalmente una `NullPointerException`. Ejecútelo y use la consulta `{job="vector_app_logs"} |= "NullPointerException"` en Grafana para localizarlo.
- **Enriquecimiento con VRL:** Modifique la sección `[transforms.enrich]` en `vector.toml` para agregar un campo estático al evento (ej. `.environment = "dev"`). Verifique que el campo aparece en los logs de Loki.
- **Censura de datos sensibles:** Añada una transformación VRL que elimine un campo del evento antes de enviarlo a Loki (ej. `del(."process.thread.name")`).
- **Múltiples destinos:** Configure un segundo sink en `vector.toml` que además de Loki escriba los eventos en un archivo local (type = "file"). Esto ilustra el enrutamiento a múltiples backends simultáneamente.
- **Comparar recursos:** Ejecute `docker stats` con el stack Vector activo y compare el consumo de memoria del contenedor `vector` frente al de `fluentd` o `logstash` en las guías anteriores.

---

## 🛠️ 10. Troubleshooting

**Error común:** Vector no arranca — `no such file or directory: /etc/vector/vector.yaml`.

**Solución:** La imagen `timberio/vector` busca `/etc/vector/vector.yaml` por defecto. Asegúrese de incluir `command: ["--config", "/etc/vector/vector.toml"]` en el servicio para apuntar al archivo TOML correcto.

---

**Error común:** El healthcheck de Vector falla con `wget: can't connect to remote host`.

**Causa:** Dos posibles razones: (1) el bloque `[api]` no está habilitado en `vector.toml`, o (2) busybox `wget` no soporta `--spider`. 

**Solución:** Verifique que `vector.toml` incluya `[api]` con `enabled = true`, y use `wget -q -O /dev/null http://127.0.0.1:8686/health` en el healthcheck (no `--spider` y con `127.0.0.1` explícito).

---

**Error común:** Error de VRL `unnecessary error coalescing operation` al usar `."log.level" ?? "unknown"`.

**Solución:** En VRL, el operador `??` es para *error-coalescing* (cuando una expresión puede fallar). El acceso a un campo (`."log.level"`) no falla — devuelve `null` si el campo no existe. Para null-coalescing, use el operador lógico `||`: `.level = ."log.level" || "unknown"`.

---

**Error común:** Los logs no aparecen en Grafana aunque Vector está corriendo.

**Solución:** Verifique que la datasource Loki esté aprovisionada en Grafana (carpeta `grafana/provisioning/datasources/`). Confirme que el pipeline Vector recibe datos consultando la API: `curl http://localhost:8686/graphql` (responde con el esquema GraphQL si está activo). Revise los logs de Vector con `docker compose logs vector`.

---

## 📚 Referencias

- Vector – https://vector.dev/docs/
- Vector Remap Language (VRL) – https://vrl.dev
- Loki + Vector – https://grafana.com/docs/loki/latest/send-data/vector/
- Grafana – https://grafana.com/docs/grafana/latest/

---

ℹ️ *Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
