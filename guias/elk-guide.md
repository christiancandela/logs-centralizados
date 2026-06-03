# Centralización de Logs con ELK Stack

> *Guía práctica para implementar una solución básica de centralización de logs usando Docker Compose y el stack ELK, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.*

---

## Objetivo de la guía

Implementar y validar una arquitectura básica de centralización de logs mediante Docker Compose y el stack ELK, como ejercicio aplicado de los conceptos de observabilidad estudiados previamente.

---

## Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar aplicaciones para emitir logs estructurados.
- Analizar y correlacionar eventos centralizados.
- Reconocer desafíos y limitaciones de una solución básica de logging.

---

## Propósito y alcance del recurso

El propósito principal de este recurso es guiar el diseño, despliegue y uso de una **arquitectura básica de centralización de logs** utilizando contenedores Docker y el stack ELK (Elasticsearch, Logstash y Kibana).

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un **entorno de laboratorio reproducible**, que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un **caso de estudio técnico**, que ilustra la integración entre aplicaciones Java (Quarkus y Logback) y una plataforma de observabilidad.

El alcance del recurso se limita a la **centralización y visualización de logs**. No se abordan en profundidad otros pilares de la observabilidad, como métricas o trazas distribuidas, aunque se dejan sentadas las bases conceptuales para su integración futura.

Aunque la implementación se apoya en el stack ELK, los principios abordados son **transferibles a otros ecosistemas de observabilidad**.

---

## 1. Observabilidad y centralización de logs

En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de señales externas. Los **logs** constituyen una fuente primaria de información debido a su riqueza semántica y contextual.

La **centralización de logs** mitiga la dispersión inherente a los sistemas distribuidos, consolidando los registros generados por múltiples componentes en un repositorio común que facilita su análisis, correlación temporal y visualización.

---

## 2. Requisitos previos

- Docker instalado  
  https://docs.docker.com/engine/install/
- Docker Compose  
  https://docs.docker.com/compose/install/
- Al menos **8 GB de RAM** libres

### Dimensionamiento de recursos

**Consumo estimado del stack:** ~5 GB de RAM en estado estable.

| Servicio | Función en el pipeline | `mem_limit` por defecto |
|---|---|---|
| `elasticsearch` | Almacenamiento e indexación de los logs | 2g |
| `logstash` | Recolección y procesamiento (parsing, transformación) | 1g |
| `kibana` | Visualización y exploración de los datos | 1g |
| `logs.producer` | Aplicación Quarkus productora de logs | 512m |

Los límites están parametrizados vía `.env` y pueden ajustarse sin editar el `docker-compose.yml`:

```bash
ELASTICSEARCH_MEM_LIMIT=2g
LOGSTASH_MEM_LIMIT=1g
KIBANA_MEM_LIMIT=1g
PRODUCER_MEM_LIMIT=512m
```

> [!WARNING]
> En Linux/WSL, Elasticsearch requiere que el host tenga `vm.max_map_count ≥ 262144`.

---

## 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
├── logstash/
│   └── pipelines/
│       └── ecs.conf
└── .env
```

---

## 4. Arquitectura de la solución

```
[Aplicaciones Java/Quarkus] --- (TCP JSON) ---> [Logstash] ---> [Elasticsearch] ---> [Kibana]
```

La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- **Logstash**: encargado de la ingestión, procesamiento y transformación de logs generados por las aplicaciones.
- **Elasticsearch**: motor de almacenamiento e indexación distribuida, que permite la búsqueda eficiente de eventos.
- **Kibana**: capa de visualización y exploración de los datos centralizados.

El uso de **Docker Compose** permite describir y desplegar la arquitectura como código, garantizando la **portabilidad, reproducibilidad y facilidad de experimentación** del entorno, características fundamentales en un contexto formativo.

---

## 5. Implementación de la arquitectura conceptual con ELK

### 5.1 docker-compose.yml

```yaml
services:
  logs.producer:
    build:
      context: logs.producer
      dockerfile: src/main/docker/Dockerfile.compose
    mem_limit: ${PRODUCER_MEM_LIMIT:-512m}
    ports:
      - "8080:8080"
    environment:
      LOGSTASH_HOST: logstash
    depends_on:
      logstash:
        condition: service_healthy

  elasticsearch:
    image: docker.io/elasticsearch:9.4.1
    container_name: elasticsearch
    mem_limit: ${ELASTICSEARCH_MEM_LIMIT:-2g}
    ports:
      - "9200:9200"
      - "9300:9300"
    environment:
      ES_JAVA_OPTS: "-Xms512m -Xmx512m"
      discovery.type: "single-node"
      cluster.routing.allocation.disk.threshold_enabled: false
      xpack.security.enabled: false
    volumes:
      - es_data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 30s

  logstash:
    image: docker.io/logstash:9.4.1
    container_name: logstash
    mem_limit: ${LOGSTASH_MEM_LIMIT:-1g}
    volumes:
      - source: ./logstash/pipelines
        target: /usr/share/logstash/pipeline
        type: bind
    ports:
      - "4560:4560"
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9600/ || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 10s
    depends_on:
      elasticsearch:
        condition: service_healthy

  kibana:
    image: docker.io/kibana:9.4.1
    container_name: kibana
    mem_limit: ${KIBANA_MEM_LIMIT:-1g}
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
      xpack.fleet.enabled: "false"
    depends_on:
      elasticsearch:
        condition: service_healthy

volumes:
  es_data:
```

---

### 5.2 Pipeline de Logstash (`ecs.conf`)

```text
input {
  tcp {
    port => 4560
    codec => json
  }
}

filter {
  if ![span][id] and [mdc][spanId] {
    mutate { rename => { "[mdc][spanId]" => "[span][id]" } }
  }
  if ![trace][id] and [mdc][traceId] {
    mutate { rename => { "[mdc][traceId]" => "[trace][id]" } }
  }
}

output {
  stdout {}
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    data_stream => true
    data_stream_auto_routing => false
    data_stream_type => "logs"
    data_stream_dataset => "producer"
    data_stream_namespace => "default"
  }
}
```

> [!NOTE]
> **Elasticsearch 9.x:** A partir de la versión 9, el output de Logstash utiliza *data streams* en lugar de índices con fecha (`logstash-YYYY.MM.dd`). La configuración anterior crea el data stream `logs-producer-default`, que sigue la convención `{type}-{dataset}-{namespace}` definida por ECS. Esto es transparente para la visualización en Kibana.

---

## 6. Despliegue y validación

### Inicialización de los servicios

El despliegue del entorno se realiza mediante un único comando, el cual levanta de forma coordinada todos los componentes definidos en el archivo `docker-compose.yml`.

```bash
docker compose up -d
```

---

### Validación de los servicios

La validación del entorno permite comprobar que los contenedores asociados a Elasticsearch, Logstash y Kibana se encuentran en ejecución y disponibles.

```bash
docker compose ps
```

---

### Persistencia y configuración del entorno

Se emplean **volúmenes Docker** para garantizar la persistencia de los datos almacenados en **Elasticsearch**, incluso ante reinicios del entorno.

---

## 7. Emisión de logs desde aplicaciones

### 7.1 Aplicaciones Quarkus

El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en **Quarkus**, utilizando **logging estructurado en formato JSON** y el estándar **ECS (Elastic Common Schema)**.  
Esta aproximación favorece la **normalización semántica de los eventos**, facilitando su procesamiento, correlación y análisis posterior dentro de la plataforma de centralización de logs.

- En caso de no tener una aplicación puede crear con el siguiente comando.

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest,logging-json' \
    -DnoCode
```

- Configure su aplicación para que los logs sean enviados a Logstash. (**`application.properties`**)

```properties
quarkus.log.console.json=false
quarkus.log.socket.enable=true
quarkus.log.socket.json=true
# Cuando se ejecuta desde el IDE apunta a localhost; docker compose inyecta LOGSTASH_HOST=logstash
quarkus.log.socket.endpoint=${LOGSTASH_HOST:localhost}:4560
quarkus.log.socket.json.exception-output-type=formatted
quarkus.log.socket.json.log-format=ECS
```

**Uso del logger:**

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

---

### 7.2 Otras aplicaciones Java (Logback)

Para otras aplicaciones Java que no utilizan Quarkus, el recurso presenta un ejemplo basado en **Logback**, empleando un *encoder* compatible con Logstash para la generación de logs estructurados en formato JSON.

Este enfoque permite ilustrar cómo aplicaciones Java tradicionales pueden integrarse a una arquitectura de centralización de logs, aun cuando no provean soporte nativo para estándares como ECS, resaltando la importancia de la estructuración y consistencia de los eventos generados.

```xml
<dependency>
  <groupId>ch.qos.logback</groupId>
  <artifactId>logback-classic</artifactId>
  <version>1.5.18</version>
</dependency>
<dependency>
  <groupId>net.logstash.logback</groupId>
  <artifactId>logstash-logback-encoder</artifactId>
  <version>8.1</version>
</dependency>
```

Configura `logback.xml` para enviar logs a Logstash:

```xml
<configuration>
  <appender name="logstash" class="net.logstash.logback.appender.LogstashTcpSocketAppender">
    <destination>localhost:4560</destination>
    <encoder class="net.logstash.logback.encoder.LogstashEncoder">
      <customFields>{"appname":"tu-aplicacion","environment":"dev"}</customFields>
      <includeContext>true</includeContext>
      <timeZone>UTC</timeZone>
    </encoder>
  </appender>

  <root level="INFO">
    <appender-ref ref="logstash" />
  </root>
</configuration>
```

---

## 8. Visualización en Kibana

Una vez centralizados, los logs pueden ser explorados mediante Kibana, permitiendo:

- Búsqueda textual y estructurada.
- Filtros temporales.
- Identificación de patrones y anomalías.

Estas capacidades resultan especialmente relevantes en contextos educativos para ilustrar procesos de diagnóstico y análisis de fallos.

Accede a:

```
http://localhost:5601
```

**Opción A — Logs Explorer (recomendada):**

**Observability → Logs → Logs Explorer**

Selecciona la fuente `logs-producer-default` para ver únicamente los eventos de la aplicación.

**Opción B — Discover:**

**Hamburger menu → Discover**

Crea o selecciona el data view `logs-*` con campo de tiempo `@timestamp`. Esta vista muestra todos los data streams que coinciden con el patrón.

---

## 9. Actividades de profundización

- **Simular fallos y rastrear su origen:** El endpoint `GET /api/error` de la aplicación de ejemplo genera intencionalmente una `NullPointerException`. Ejecútelo y utilice Kibana para localizar el *stacktrace* del error, validando la ventaja del campo `exception` en formato ECS estructurado.
- Comparar ECS con esquemas personalizados: modifique el pipeline de Logstash para agregar un campo personalizado y observe cómo se indexa en Elasticsearch.
- Desplegar dos instancias de `logs.producer` en puertos distintos y correlacionar sus eventos en Kibana mediante el campo `service.name`.
- Identificar las implicaciones de seguridad del envío TCP sin autenticación ni cifrado.

### Cuestionario de análisis crítico

1. ¿Qué ventaja concreta ofrece el Elastic Common Schema (ECS) frente a un esquema de logs personalizado cuando se correlacionan eventos de múltiples servicios en Kibana Discover?
2. El pipeline de Logstash de esta guía usa un appender TCP sin TLS. Analice qué riesgos de seguridad introduce este diseño y qué cambios de configuración serían necesarios para mitigarlos en un entorno productivo.
3. Evalúe las diferencias arquitectónicas entre los data streams de Elasticsearch 9.x (usados en esta guía) y los índices con fecha (`logs-YYYY.MM.dd`): ¿en qué escenarios concretos justificaría elegir uno sobre el otro?

---

## 10. Troubleshooting

**Error común:** El contenedor `elasticsearch` se detiene inesperadamente o marca estado `Exit 78` / `Exit 137`.

**Solución:** Elasticsearch requiere configurar la memoria virtual del sistema anfitrión. En sistemas Linux o entornos WSL, ejecute el siguiente comando en la terminal de su máquina (fuera del contenedor) antes de iniciar `docker compose up -d`:
```bash
sudo sysctl -w vm.max_map_count=262144
```

---

**Error común:** Kibana muestra el mensaje *"Kibana cannot connect to the Elastic Package Registry"* al abrir la interfaz.

**Explicación:** Kibana 9.x intenta conectarse por defecto al registro externo de integraciones de Fleet (`epr.elastic.co`). En un entorno de laboratorio local sin acceso a internet este intento falla. El aviso es **no bloqueante**: Kibana funciona correctamente para visualización de logs.

**Solución:** El archivo `docker-compose.yml` de esta guía ya incluye `xpack.fleet.enabled: "false"` en el servicio Kibana, lo que elimina el aviso. Si crea su propio `docker-compose.yml`, asegúrese de incluir esa variable de entorno.

---

## Referencias

- Logstash – https://www.elastic.co/docs/reference/logstash
- Elasticsearch – https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
- Kibana – https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-kibana-with-docker
- Elastic Common Schema – https://www.elastic.co/guide/en/ecs/current/ecs-reference.html

---

*Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
