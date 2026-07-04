# Centralización de Logs con OLO Stack (OpenSearch + Logstash)

> *Guía práctica para implementar una solución básica de centralización de logs utilizando Docker Compose y el stack OLO, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.*

## Objetivo de la guía

Implementar y validar una arquitectura básica de centralización de logs mediante Docker Compose y el stack **OLO (OpenSearch, Logstash y OpenSearch Dashboards)**, como ejercicio aplicado de los conceptos de observabilidad estudiados previamente.

> [!NOTE]
> **La denominación "OLO":** Este acrónimo es una convención adoptada en este recurso educativo para nombrar el stack OpenSearch + Logstash + OpenSearch Dashboards, de manera análoga a como la industria denomina "ELK" al stack Elasticsearch + Logstash + Kibana. No es un término estándar de la industria; al buscar referencias externas sobre este stack conviene usar los nombres individuales de los componentes o buscar documentación de OpenSearch directamente.

## Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar aplicaciones para emitir logs estructurados.
- Analizar y correlacionar eventos centralizados.
- Reconocer desafíos y limitaciones de una solución básica de logging.

**Tiempo estimado:** 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

**Evidencias esperadas:** al finalizar la guía, el estudiante debe contar con (a) el archivo `docker-compose.yml` y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en OpenSearch Dashboards que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script `smoke_test.sh` de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

## Propósito y alcance del recurso

El propósito principal de este recurso es guiar el diseño, despliegue y uso de una **arquitectura básica de centralización de logs** utilizando OpenSearch, Logstash y OpenSearch Dashboards.

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un **entorno de laboratorio reproducible**, que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un **caso de estudio técnico**, que ilustra la integración entre aplicaciones Java (Quarkus y Logback) y una plataforma de observabilidad.

El alcance del recurso se limita a la **centralización y visualización de logs**. No se abordan métricas ni trazas distribuidas, aunque se dejan sentadas las bases conceptuales para su integración futura.

## 1. Observabilidad y centralización de logs

En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de las señales externas que este produce durante su ejecución. Los **logs** constituyen una fuente primaria de información debido a su riqueza semántica y contextual, y la **centralización de logs** mitiga la dispersión inherente a los sistemas distribuidos consolidando los registros de múltiples componentes en un repositorio común.

Si ya recorriste la guía de ELK, buena parte de esta te resultará familiar (y eso es precisamente lo interesante). El stack **OLO** (OpenSearch + Logstash + OpenSearch Dashboards) comparte exactamente el mismo paradigma de almacenamiento que ELK: el **índice invertido** (marco conceptual, §5.7.3). La diferencia entre ambos no es, en el fondo, técnica, sino de gobernanza del software libre.

### ¿Por qué existe OpenSearch si ya existía Elasticsearch?

En 2021, Elastic (la empresa detrás de Elasticsearch) cambió la licencia de su producto, abandonando la licencia open source Apache 2.0 por una licencia más restrictiva (SSPL). En respuesta, Amazon y la comunidad crearon un *fork* (una bifurcación) a partir de la última versión Apache 2.0 de Elasticsearch y Kibana, dando origen a **OpenSearch** y **OpenSearch Dashboards**.

Observa la lección de fondo: la elección de una tecnología no depende únicamente de sus capacidades técnicas, sino también del modelo de licenciamiento y de la gobernanza del proyecto que la sostiene. Para un ingeniero, anticipar estas implicaciones es tan importante como dominar la herramienta misma.

En lo conceptual, OLO se mapea a la arquitectura de cuatro etapas igual que ELK, componente por componente:

| Componente | Etapa conceptual | Equivalente en ELK |
|---|---|---|
| **Logstash** | Recolección + Procesamiento | Logstash |
| **OpenSearch** | Almacenamiento + Búsqueda (índice invertido) | Elasticsearch |
| **OpenSearch Dashboards** | Visualización | Kibana |

Esta correspondencia casi exacta no es casual: ambos stacks descienden del mismo código base. Comprenderla te permite transferir de inmediato a OLO todo lo aprendido sobre el paradigma de índice invertido en la guía de ELK.

## 2. Requisitos previos

- Docker instalado  
  https://docs.docker.com/engine/install/
- Docker Compose  
  https://docs.docker.com/compose/install/
- Al menos **8 GB de RAM** libres

> [!NOTE]
> **Versiones:** Esta guía usa **OpenSearch 3.0**, la versión más reciente de la línea principal. La guía GELF/Graylog utiliza OpenSearch 2.12 porque Graylog 7.1 requiere compatibilidad con la API de Elasticsearch 7.x que solo mantiene la rama 2.x. Ambas elecciones son intencionadas y correctas para cada contexto.

### Dimensionamiento de recursos

El stack OLO es intensivo en memoria, ya que combina un motor de indexación distribuida (OpenSearch), un procesador de logs sobre la JVM (Logstash) y una capa de visualización (OpenSearch Dashboards). El **consumo estimado del stack es de ~5 GB de RAM en estado estable**, por lo que se recomienda disponer de al menos 8 GB libres para operar con holgura.

Cada servicio del `docker-compose.yml` declara un límite de memoria (`mem_limit`) que acota su consumo y previene que un único contenedor agote la memoria del anfitrión:

| Servicio | Función en el pipeline | `mem_limit` por defecto |
|----------|------------------------|-------------------------|
| `opensearch` | Almacenamiento e indexación de eventos | `2g` |
| `logstash` | Ingestión, procesamiento y transformación de logs | `1g` |
| `dashboards` | Visualización y exploración (OpenSearch Dashboards) | `1g` |
| `logs.producer` | Aplicación productora de logs (Quarkus) | `512m` |

Estos límites están **parametrizados mediante variables de entorno**, de modo que pueden ajustarse sin modificar el `docker-compose.yml`. Defina los valores en un archivo `.env` ubicado junto al `docker-compose.yml`:

```bash
OPENSEARCH_MEM_LIMIT=2g
LOGSTASH_MEM_LIMIT=1g
DASHBOARDS_MEM_LIMIT=1g
PRODUCER_MEM_LIMIT=512m
```

> [!IMPORTANT]
> En sistemas **Linux o entornos WSL**, OpenSearch requiere que la memoria virtual del anfitrión cumpla `vm.max_map_count ≥ 262144`. Configúrelo antes de iniciar el entorno (véase la sección de *Troubleshooting*).

## 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
├── logstash/
│   ├── Dockerfile
│   └── pipelines/
│       └── logstash.conf
└── .env
```

## 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
        |
        | (TCP JSON)
        v
     [Logstash]
        |
        v
   [OpenSearch] ---> [OpenSearch Dashboards]
```

La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- **Logstash**: encargado de la ingestión, procesamiento y transformación de logs generados por las aplicaciones.
- **OpenSearch**: motor de almacenamiento e indexación distribuida, que permite la búsqueda eficiente de eventos.
- **OpenSearch Dashboards**: capa de visualización y exploración de los datos centralizados.

El uso de **Docker Compose** permite describir y desplegar la arquitectura como código, garantizando la **portabilidad, reproducibilidad y facilidad de experimentación** del entorno, características fundamentales en un contexto formativo.

## 5. Implementación de la arquitectura conceptual con OLO

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

  opensearch:
    image: opensearchproject/opensearch:3.0.0
    mem_limit: ${OPENSEARCH_MEM_LIMIT:-2g}
    container_name: opensearch
    environment:
      - discovery.type=single-node
      - DISABLE_SECURITY_PLUGIN=true
      - bootstrap.memory_lock=true
      - OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - opensearch_data:/usr/share/opensearch/data
    ports:
      - "9200:9200"
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 30s

  dashboards:
    image: opensearchproject/opensearch-dashboards:3.0.0
    mem_limit: ${DASHBOARDS_MEM_LIMIT:-1g}
    container_name: dashboards
    ports:
      - "5601:5601"
    environment:
      - OPENSEARCH_HOSTS=http://opensearch:9200
      - DISABLE_SECURITY_DASHBOARDS_PLUGIN=true
    depends_on:
      opensearch:
        condition: service_healthy

  logstash:
    build: ./logstash
    mem_limit: ${LOGSTASH_MEM_LIMIT:-1g}
    container_name: logstash
    volumes:
      - source: ./logstash/pipelines
        target: /usr/share/logstash/pipeline
        type: bind
    ports:
      - "4560:4560"
    environment:
      - xpack.monitoring.enabled=false
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9600/ || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 10s
    depends_on:
      opensearch:
        condition: service_healthy

volumes:
  opensearch_data:
```

### 5.2 Pipeline de Logstash (`logstash.conf`)

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
  opensearch {
    hosts => ["http://opensearch:9200"]
    index => "logs-producer-%{+YYYY.MM.dd}"
    manage_template => false
  }
}
```

### 5.3 Dockerfile de Logstash

```dockerfile
FROM docker.io/logstash:9.4.1
RUN logstash-plugin install logstash-output-opensearch
```

> [!NOTE]
> La versión 2.x del plugin `logstash-output-opensearch` tiene un bug de compatibilidad con JRuby 10 (incluido en Logstash 9.x) que impide la instalación de templates. Por eso el pipeline incluye `manage_template => false`, lo que hace que Logstash cree los índices dinámicamente sin plantilla previa. En producción se recomienda definir un index template explícito en OpenSearch.

## 6. Despliegue y validación

### Inicialización de los servicios

El despliegue del entorno se realiza mediante un único comando, el cual levanta de forma coordinada todos los componentes definidos en el archivo `docker-compose.yml`.

```bash
docker compose up -d
```

### Validación de los servicios

La validación del entorno permite comprobar que los contenedores asociados a OpenSearch, Logstash y OpenSearch Dashboards se encuentran en ejecución y disponibles.

```bash
docker compose ps
```

### Persistencia y configuración del entorno

Se emplean **volúmenes Docker** para garantizar la persistencia de los datos almacenados en **OpenSearch**, incluso ante reinicios del entorno.

Opensearch-dashboards requiere una configuración adicional para facilitar la visualización de logs. El siguiente comando pretende crear un index-pattern en el Dashboard con el fin de poder visualizar los logs generados por logstash.

> [!IMPORTANT]
> Antes de ejecutar el siguiente comando, asegúrese de que OpenSearch Dashboards haya finalizado su inicialización y sea accesible desde el navegador.

```shell
curl -XPOST "http://localhost:5601/api/saved_objects/index-pattern" \
  -H "Content-Type: application/json" \
  -H "osd-xsrf: true" \
  -d '{
    "attributes": {
      "title": "logs-producer-*",
      "timeFieldName": "@timestamp"
    }
  }'
```

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

### 7.2 Otras aplicaciones Java (Logback)

Para otras aplicaciones Java que no utilizan Quarkus, el recurso presenta un ejemplo basado en **Logback**, empleando un *encoder* compatible con Logstash para la generación de logs estructurados en formato JSON.

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

## 8. Visualización en OpenSearch Dashboards

Una vez centralizados, los logs pueden ser explorados mediante OpenSearch Dashboards, permitiendo:

- Búsqueda textual y estructurada.
- Filtros temporales.
- Identificación de patrones y anomalías.

Estas capacidades resultan especialmente relevantes en contextos educativos para ilustrar procesos de diagnóstico y análisis de fallos.

Accede a:

```
http://localhost:5601
```

Ingrese a **OpenSearch Dashboards → Discover**: una vez creado el index pattern `logs-producer-*` (paso anterior), selecciónelo y verá el registro de los logs con todos sus campos ECS.

Alternativamente, acceda a **Observability → Logs** y en el campo PPL ingrese:
```
source = logs-producer-*
```

## 9. Actividades de profundización

- **Simular fallos y rastrear su origen:** El endpoint `GET /api/error` de la aplicación de ejemplo genera intencionalmente una `NullPointerException`. Ejecútelo y utilice OpenSearch Dashboards para localizar el evento de error e inspeccionar el stacktrace estructurado.
- Comparar el modelo de índices con fecha (`logs-producer-YYYY.MM.dd`) de este stack frente a los data streams de Elasticsearch 9.x de la guía anterior.
- Desplegar dos instancias de `logs.producer` y distinguirlas en Discover por el campo `service.name`.
- Identificar las implicaciones de seguridad del envío TCP sin autenticación ni cifrado.

### Cuestionario de análisis crítico

1. OpenSearch es un fork de Elasticsearch. Explique qué es el campo `manage_template => false` en el pipeline de Logstash de esta guía y por qué es necesario específicamente con el plugin `logstash-output-opensearch` 2.x sobre Logstash 9.x.
2. Compare el modelo de índices con fecha (`logs-producer-YYYY.MM.dd`) que usa este stack frente a los data streams de Elasticsearch 9.x de la guía ELK: ¿qué implicaciones tiene cada enfoque para la gestión del ciclo de vida de los datos (ILM)?
3. Evalúe las razones técnicas y de gobernanza que llevaron a la bifurcación de OpenSearch desde Elasticsearch 7.10. ¿Cómo afecta esa historia a la elección de versión en esta guía (OpenSearch 3.0) frente a la guía GELF (OpenSearch 2.12)?

## 10. Troubleshooting

**Error común:** El contenedor `opensearch` se detiene inesperadamente o marca estado `Exit 78` / `Exit 137`.

**Solución:** OpenSearch requiere configurar la memoria virtual del sistema anfitrión. En sistemas Linux o entornos WSL, ejecute el siguiente comando en la terminal de su máquina (fuera del contenedor) antes de iniciar `docker compose up -d`:
```bash
sudo sysctl -w vm.max_map_count=262144
```

---

**Error común:** Logstash arranca pero no indexa documentos; en sus logs aparece `undefined method 'exists?' for class File`.

**Explicación:** El plugin `logstash-output-opensearch` 2.x tiene un bug de compatibilidad con JRuby 10 (Logstash 9.x) al intentar instalar templates de índice. El pipeline de esta guía ya incluye `manage_template => false` para evitarlo. Si crea su propio pipeline, asegúrese de incluir esa opción.

## Referencias

- OpenSearch – https://opensearch.org
- OpenSearch (Docker) – https://docs.opensearch.org/docs/latest/install-and-configure/install-opensearch/docker/
- OpenSearch Dashboards – https://docs.opensearch.org/docs/latest/dashboards/
- Logstash – https://www.elastic.co/docs/reference/logstash
- Elastic Common Schema – https://www.elastic.co/guide/en/ecs/current/ecs-reference.html

---

*Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
