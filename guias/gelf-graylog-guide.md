# 🧠 Centralización de Logs con GELF y Graylog

> *Guía práctica para implementar una solución básica de centralización de logs utilizando Docker Compose y GELF/Graylog, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.*

---

## 🌟 Objetivo de la guía

Implementar y validar una arquitectura básica de centralización de logs mediante Docker Compose, utilizando **GELF** como protocolo de transporte y **Graylog** como plataforma de ingestión y visualización, como ejercicio aplicado de los conceptos de observabilidad estudiados previamente.

---

## 🎯 Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs basada en Graylog.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar Graylog para recibir eventos vía **GELF UDP**.
- Configurar aplicaciones Java para emitir logs mediante GELF (Quarkus y Logback).
- Explorar y consultar logs centralizados desde la interfaz de Graylog.
- Reconocer desafíos y limitaciones de un envío basado en UDP y mensajes fragmentados.

---

## 🧭 Propósito y alcance del recurso

El propósito principal de este recurso es guiar el despliegue y uso de una **arquitectura básica de centralización de logs** basada en Graylog, en un entorno local y reproducible mediante Docker Compose.

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un **entorno de laboratorio reproducible**, que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un **caso de estudio técnico**, que ilustra la integración entre aplicaciones Java (Quarkus y Logback) y una plataforma de observabilidad.

El alcance del recurso se limita a la **centralización y visualización de logs**. No se abordan métricas ni trazas distribuidas, aunque se dejan sentadas bases conceptuales para integraciones futuras.

---

## 🧩 1. Observabilidad y centralización de logs

En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de señales externas que este produce durante su ejecución. Los **logs** constituyen una fuente primaria de información por su riqueza semántica y contextual.

La **centralización de logs** mitiga la dispersión inherente a los sistemas distribuidos, consolidando los registros generados por múltiples componentes en un repositorio común que facilita su análisis, correlación temporal y visualización.

---

## ⚙️ 2. Requisitos previos

- Docker instalado  
  https://docs.docker.com/engine/install/
- Docker Compose  
  https://docs.docker.com/compose/install/
- Al menos **8 GB de RAM** libres

> ℹ️ **Nota sobre versiones:** Esta guía usa **OpenSearch 2.12**, no la versión 3.x empleada en la guía OLO. Graylog 7.1 requiere compatibilidad con la API de Elasticsearch 7.x, que OpenSearch 2.x mantiene; la rama 3.x introdujo cambios de API que Graylog aún no soporta. Ambas elecciones son intencionadas y correctas para cada contexto.

---

## 📂 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
```

---

## 📊 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
        |
        |   GELF (UDP 12201)
        v
     [Graylog 7.1]
        |             \
        v              v
  [OpenSearch 2.12]  [MongoDB 7.0]
  (almacenamiento)  (configuración)
```

La arquitectura implementada en este recurso se fundamenta en **un protocolo de transporte y tres servicios**:

- **GELF (Graylog Extended Log Format)**: protocolo estructurado de envío de logs vía **UDP** (puerto 12201). A diferencia de los stacks anteriores, el transporte es responsabilidad del protocolo, no de un agente recolector separado.
- **Graylog**: plataforma de ingestión, búsqueda y visualización de logs.
- **OpenSearch**: motor de almacenamiento e indexación de eventos.
- **MongoDB**: almacenamiento de configuración y metadatos de Graylog.

El uso de **Docker Compose** permite describir y desplegar la arquitectura como código, garantizando la **portabilidad, reproducibilidad y facilidad de experimentación** del entorno.

---

## 🛠️ 5. Implementación de la arquitectura conceptual con GELF y Graylog

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
      GRAYLOG_HOST: graylog
    depends_on:
      graylog:
        condition: service_healthy

  mongo:
    image: mongo:7.0
    container_name: mongo
    volumes:
      - mongo_data:/data/db

  opensearch:
    image: opensearchproject/opensearch:2.12.0
    container_name: opensearch
    environment:
      - discovery.type=single-node
      - DISABLE_SECURITY_PLUGIN=true
      - OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m
      - bootstrap.memory_lock=true
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - opensearch_data:/usr/share/opensearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 30s

  graylog:
    image: graylog/graylog:7.1.1-1
    container_name: graylog
    ports:
      - "9000:9000"
      - "12201:12201/udp"
      - "1514:1514"
    environment:
      GRAYLOG_MONGODB_URI: mongodb://mongo:27017/graylog
      GRAYLOG_HTTP_EXTERNAL_URI: "http://127.0.0.1:9000/"
      GRAYLOG_HTTP_BIND_ADDRESS: "0.0.0.0:9000"
      GRAYLOG_ELASTICSEARCH_HOSTS: "http://opensearch:9200"
      # Reduce journal size para entornos con disco limitado (por defecto 5 GB)
      GRAYLOG_MESSAGE_JOURNAL_MAX_SIZE: "512mb"
      # CHANGE ME (must be at least 16 characters)
      GRAYLOG_PASSWORD_SECRET: "forpasswordencryption"
      # Password: admin
      GRAYLOG_ROOT_PASSWORD_SHA2: "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918"
    volumes:
      - graylog_data:/usr/share/graylog/data
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9000/api/system/lbstatus | grep -q ALIVE || exit 1"]
      interval: 15s
      timeout: 10s
      retries: 20
      start_period: 60s
    depends_on:
      mongo:
        condition: service_started
      opensearch:
        condition: service_healthy
    entrypoint: "/usr/bin/tini -- /docker-entrypoint.sh"

volumes:
  mongo_data:
  opensearch_data:
  graylog_data:
```

---

## ▶️ 6. Despliegue y validación

### Inicialización de los servicios

```bash
docker compose up -d
```

### Validación de los servicios

```bash
docker compose ps
```

Salida esperada (referencial):

```text
NAME         STATUS
mongo        Up
opensearch   Up (healthy)
graylog      Up (healthy)
logs.producer  Up
```

---

### Creación de la entrada GELF UDP (Input)

Antes de que los logs puedan ser recibidos, Graylog debe tener configurado un **input**. Espere a que Graylog esté disponible en `http://localhost:9000`, luego ejecute:

```bash
curl -H "Content-Type: application/json" \
     -H "Authorization: Basic YWRtaW46YWRtaW4=" \
     -H "X-Requested-By: curl" \
     -X POST \
     -d '{"title":"GELF UDP","configuration":{"recv_buffer_size":262144,"bind_address":"0.0.0.0","port":12201,"decompress_size_limit":8388608},"type":"org.graylog2.inputs.gelf.udp.GELFUDPInput","global":true}' \
     http://localhost:9000/api/system/inputs
```

> ℹ️ La cabecera `Authorization: Basic YWRtaW46YWRtaW4=` corresponde a `admin:admin` en Base64. Alternativamente, puede crear el input desde la interfaz web: **System → Inputs → GELF UDP → Launch new input**.

---

## 🔌 7. Emisión de logs desde aplicaciones

### 7.1 Aplicaciones Quarkus

El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en **Quarkus**, utilizando la extensión `logging-gelf` que envía logs directamente a Graylog mediante el protocolo GELF/UDP.

- En caso de no tener una aplicación puede crear con el siguiente comando.

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest,logging-gelf' \
    -DnoCode
```

- Configure su aplicación para que los logs sean enviados a Graylog. (**`application.properties`**)

```properties
quarkus.log.handler.gelf.enabled=true
# Cuando se ejecuta desde el IDE apunta a localhost; docker compose inyecta GRAYLOG_HOST=graylog
quarkus.log.handler.gelf.host=${GRAYLOG_HOST:localhost}
quarkus.log.handler.gelf.port=12201
```

> ℹ️ **Nota:** Al usar `logging-gelf`, no se requiere la extensión `logging-json`. La consola mostrará logs en formato estándar (texto plano) y los eventos estructurados se enviarán por UDP a Graylog.

**Uso del logger:**

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

---

### 7.2 Otras aplicaciones Java (Logback)

Para aplicaciones Java que no utilizan Quarkus, se puede enviar GELF mediante Logback con la librería `logback-gelf`.

```xml
<dependency>
  <groupId>de.siegmar</groupId>
  <artifactId>logback-gelf</artifactId>
  <version>3.0.0</version>
</dependency>
```

Configuración de `logback.xml`:

```xml
<configuration>
  <appender name="GELF" class="de.siegmar.logbackgelf.GelfUdpAppender">
    <graylogHost>graylog</graylogHost>
    <graylogPort>12201</graylogPort>
    <maxChunkSize>508</maxChunkSize>
    <useCompression>true</useCompression>
    <layout class="de.siegmar.logbackgelf.GelfLayout">
      <originHost>mi_host</originHost>
      <includeRawMessage>false</includeRawMessage>
      <includeLevelName>true</includeLevelName>
    </layout>
  </appender>

  <root level="INFO">
    <appender-ref ref="GELF" />
  </root>
</configuration>
```

---

## 📊 8. Visualización en Graylog

Acceda a Graylog en `http://localhost:9000` con usuario `admin` y contraseña `admin`.

Ruta sugerida:

**Search → All messages**

Desde allí puede:
- Filtrar por campos (`level`, `source`, `facility`).
- Consultar con el lenguaje de búsqueda de Graylog (ej: `level:3` para errores, `message:Exception`).
- Crear streams y dashboards para análisis continuo.

---

## 🧪 9. Actividades de profundización

- **Simular fallos y rastrear su origen:** El endpoint `GET /api/error` de la aplicación de ejemplo genera intencionalmente una `NullPointerException`. Ejecútelo y utilice Graylog para localizar el evento de error, inspeccionando el stacktrace y los campos de origen.
- Comparar GELF UDP frente a envíos basados en TCP/JSON (en términos de confiabilidad y pérdida de mensajes).
- Evaluar el impacto de **fragmentación** (`maxChunkSize`) en mensajes grandes con stacktraces extensos.
- Implementar múltiples productores de logs y distinguirlos por el campo `source`.
- Analizar consideraciones de seguridad (TLS, autenticación, control de acceso) para escenarios productivos.
- **Hardening de credenciales (actividad de seguridad):** El `docker-compose.yml` de esta guía contiene credenciales de laboratorio (`GRAYLOG_PASSWORD_SECRET: "forpasswordencryption"`, contraseña `admin`). Esto es un **anti-patrón** para cualquier entorno que no sea exclusivamente local. Practique el ciclo correcto:
  1. Genere un secreto seguro con `openssl rand -hex 32` y reemplace el valor de `GRAYLOG_PASSWORD_SECRET`.
  2. Calcule el hash SHA-256 de su nueva contraseña con `echo -n "nuevaContraseña" | sha256sum` y reemplace `GRAYLOG_ROOT_PASSWORD_SHA2`.
  3. Verifique que Graylog arranque correctamente con las nuevas credenciales.
  4. Analice por qué estos valores **nunca deben almacenarse en texto claro en un repositorio de código** y explore cómo Docker Compose soporta archivos `.env` y secretos como alternativa.

### Preguntas de verificación

1. GELF en esta guía utiliza transporte UDP (puerto 12201). Explique qué ocurre con los mensajes de log cuando la red experimenta congestión o pérdida de paquetes, y por qué este comportamiento puede ser aceptable o no según el contexto de uso.
2. La fragmentación de mensajes GELF (parámetro `maxChunkSize`) es necesaria cuando el payload supera el MTU de la red. Analice cómo un stacktrace de Java de 50 líneas podría afectar la entrega de mensajes GELF y qué estrategia de configuración mitigaría el riesgo de pérdida de fragmentos.
3. Compare la arquitectura de Graylog (con su propio journal, OpenSearch y MongoDB) frente al stack ELK: ¿qué ventajas ofrece Graylog al integrar en una sola plataforma la ingestión, el almacenamiento y la visualización, y qué complejidades operativas introduce el componente MongoDB?

---

## 🛠️ 10. Troubleshooting

**Error común:** Graylog falla al iniciar con `PreflightCheckException: Journal directory has not enough free space`.

**Explicación:** Graylog reserva por defecto **5 GB** para el journal de mensajes. En entornos con Docker Desktop donde el disco del VM es limitado, esto puede fallar.

**Solución:** El `docker-compose.yml` de esta guía ya incluye `GRAYLOG_MESSAGE_JOURNAL_MAX_SIZE: "512mb"` para reducir la reserva. Si crea su propio compose, asegúrese de incluir esta variable.

---

**Error común:** El contenedor `opensearch` se detiene con `Exit 78` / `Exit 137`.

**Solución:** OpenSearch requiere configurar la memoria virtual del sistema anfitrión. En Linux o WSL:
```bash
sudo sysctl -w vm.max_map_count=262144
```

---

**Error común:** Los logs no aparecen en Graylog aunque la aplicación está corriendo.

**Solución:** Verifique que el input GELF UDP haya sido creado (sección 6). Sin el input, Graylog descarta los paquetes UDP recibidos en el puerto 12201. Confirme su existencia en **System → Inputs**.

---

## 📚 Referencias

- Graylog – https://graylog.org
- Graylog Docs (Docker) – https://docs.graylog.org/docs/docker
- GELF Format – https://go2docs.graylog.org/current/getting_in_log_data/gelf.html
- Quarkus logging-gelf – https://quarkus.io/guides/logging#gelf-log-handler

---

ℹ️ *Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
