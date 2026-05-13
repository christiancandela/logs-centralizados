# 🧠 Centralización de Logs con Fluentd

> *Guía práctica para implementar una solución básica de centralización de logs utilizando Docker Compose y Fluentd, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.*

---

## 🌟 Objetivo de la guía

Implementar y validar una arquitectura básica de centralización de logs mediante Docker Compose y Fluentd, como ejercicio aplicado de los conceptos de observabilidad estudiados previamente.

---

## 🎯 Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar aplicaciones para emitir logs hacia Fluentd.
- Analizar y correlacionar eventos centralizados.
- Reconocer desafíos y limitaciones de una solución básica de logging.

---

## 🧭 Propósito y alcance del recurso

El propósito principal de este recurso es guiar el diseño, despliegue y uso de una **arquitectura básica de centralización de logs** utilizando Fluentd, Elasticsearch y Kibana.

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un **entorno de laboratorio reproducible**, que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un **caso de estudio técnico**, que ilustra la integración entre aplicaciones Java y una plataforma de observabilidad.

El alcance del recurso se limita a la **centralización y visualización de logs**. No se abordan métricas ni trazas distribuidas, aunque se dejan sentadas las bases conceptuales para su integración futura.

---

## 🧩 1. Observabilidad y centralización de logs

En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de las señales externas que este produce durante su ejecución. Los **logs** constituyen una fuente primaria de información debido a su riqueza semántica y contextual.

La **centralización de logs** mitiga la dispersión inherente a los sistemas distribuidos, consolidando los registros generados por múltiples componentes en un repositorio común que facilita su análisis, correlación temporal y visualización.

---

## ⚙️ 2. Requisitos previos

- Docker instalado  
  https://docs.docker.com/engine/install/
- Docker Compose  
  https://docs.docker.com/compose/install/
- Al menos **8 GB de RAM** libres

---

## 📂 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
├── fluentd/
│   ├── Dockerfile
│   └── conf/
│       └── fluent.conf
└── .env
```

---

## 📊 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
        |
        | (TCP JSON)
        v
     [Fluentd]
        |
        v
 [Elasticsearch] ---> [Kibana]
```

La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- **Fluentd**: actúa como componente de **recolección y procesamiento**, desacoplando la generación de eventos de su almacenamiento y análisis posterior.
- **Elasticsearch**: motor de almacenamiento e indexación distribuida, que permite la búsqueda eficiente de eventos.
- **Kibana**: capa de visualización y exploración de los datos centralizados.

El uso de **Docker Compose** permite describir y desplegar la arquitectura como código, garantizando la **portabilidad, reproducibilidad y facilidad de experimentación** del entorno, características fundamentales en un contexto formativo.

---

## 🛠️ 5. Implementación de la arquitectura conceptual con Fluentd

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
      FLUENTD_HOST: fluentd
    depends_on:
      fluentd:
        condition: service_healthy

  elasticsearch:
    image: docker.io/elasticsearch:9.4.1
    container_name: elasticsearch
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

  kibana:
    image: docker.io/kibana:9.4.1
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
      xpack.fleet.enabled: "false"
    depends_on:
      elasticsearch:
        condition: service_healthy

  fluentd:
    build: ./fluentd
    container_name: fluentd
    volumes:
      - source: ./fluentd/conf
        target: /fluentd/etc
        type: bind
    ports:
      - "4560:4560"
    environment:
      - ELASTICSEARCH_HOST=elasticsearch
      - ELASTICSEARCH_PORT=9200
    healthcheck:
      test: ["CMD-SHELL", "ruby -rsocket -e 'TCPSocket.new(\"127.0.0.1\", 4560).close' 2>/dev/null"]
      interval: 10s
      timeout: 5s
      retries: 6
      start_period: 15s
    depends_on:
      elasticsearch:
        condition: service_healthy

volumes:
  es_data:
```

---

### 5.2 Configuración de Fluentd (`fluent.conf`)

```xml
<source>
  @type tcp
  port 4560
  bind 0.0.0.0
  <parse>
    @type json
  </parse>
  tag app.logs
</source>

<match app.logs>
  @type elasticsearch
  host "#{ENV['ELASTICSEARCH_HOST'] || 'elasticsearch'}"
  port "#{ENV['ELASTICSEARCH_PORT'] || 9200}"
  logstash_format true
  logstash_prefix logs
  <buffer>
    @type file
    path /fluentd/log/buffers/app
    flush_interval 5s
  </buffer>
</match>
```

> ℹ️ **Nota:** A diferencia de Logstash, la imagen oficial de Fluentd **no incluye** el plugin de Elasticsearch. El plugin `fluent-plugin-elasticsearch` debe instalarse al construir la imagen personalizada (ver Dockerfile en la siguiente sección). El archivo de configuración debe llamarse `fluent.conf`, que es el nombre esperado por el entrypoint del contenedor.

---

### 5.3 Dockerfile de Fluentd

```dockerfile
FROM fluent/fluentd:v1.18.0-debian
USER root
RUN gem install fluent-plugin-elasticsearch --no-document
USER fluent
```

> ℹ️ **Nota:** La imagen base de Fluentd corre como usuario no privilegiado `fluent`. La instalación de gems requiere cambiar temporalmente al usuario `root` y volver a `fluent` al finalizar.

---

## ▶️ 6. Despliegue y validación

### Inicialización de los servicios

El despliegue del entorno se realiza mediante un único comando, el cual levanta de forma coordinada todos los componentes definidos en el archivo `docker-compose.yml`.

```bash
docker compose up -d
```

### Validación de los servicios

La validación del entorno permite comprobar que los contenedores asociados a Elasticsearch, Fluentd y Kibana se encuentran en ejecución y disponibles.

```bash
docker compose ps
```

---

### Persistencia y configuración del entorno

Se emplean **volúmenes Docker** para garantizar la persistencia de los datos almacenados en **Elasticsearch**, incluso ante reinicios del entorno.

---

## 🔌 7. Emisión de logs desde aplicaciones

### 7.1 Aplicaciones Quarkus

El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en **Quarkus**, utilizando **logging estructurado en formato JSON** y el estándar **ECS (Elastic Common Schema)**.  
Fluentd recibe estos eventos a través de su plugin `in_tcp` configurado con un parser JSON, aprovechando la misma interfaz de red que ya ofrece la extensión de logging de Quarkus.

- En caso de no tener una aplicación puede crear con el siguiente comando.

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest,logging-json' \
    -DnoCode
```

- Configure su aplicación para que los logs sean enviados a Fluentd. (**`application.properties`**)

```properties
quarkus.log.console.json=false
quarkus.log.socket.enable=true
quarkus.log.socket.json=true
# Cuando se ejecuta desde el IDE apunta a localhost; docker compose inyecta FLUENTD_HOST=fluentd
quarkus.log.socket.endpoint=${FLUENTD_HOST:localhost}:4560
quarkus.log.socket.json.exception-output-type=formatted
quarkus.log.socket.json.log-format=ECS
```

**Uso del logger:**

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

---

### 7.2 Otras aplicaciones Java (Logback con Syslog)

> ⚠️ **SECCIÓN DE REFERENCIA — NO EJECUTABLE TAL COMO ESTÁ**
>
> Esta sección ilustra un patrón de integración alternativo (Syslog UDP) con fines pedagógicos. **No forma parte del `docker-compose.yml` del recurso** y no puede ejecutarse directamente sin modificaciones. Para experimentar con ella deberá: (1) agregar el source `in_syslog` a `fluent.conf`, y (2) exponer el puerto `5140:5140/udp` en el servicio `fluentd` del compose. Se incluye aquí para ampliar la comprensión de la versatilidad de Fluentd como colector multi-protocolo.

Para aplicaciones Java que no utilizan Quarkus, Fluentd puede actuar como receptor **Syslog (RFC5424) vía UDP**. Esto ilustra cómo Fluentd se integra con protocolos clásicos de red, ampliando el espectro de productores de logs compatibles.

En este caso, Fluentd expone el puerto `5140/udp` con el plugin `in_syslog` y la aplicación utiliza el `SyslogAppender` de Logback:

```xml
<dependency>
  <groupId>ch.qos.logback</groupId>
  <artifactId>logback-classic</artifactId>
  <version>1.5.18</version>
</dependency>
```

Configuración de `logback.xml`:

```xml
<configuration>
  <appender name="FLUENTD" class="ch.qos.logback.classic.net.SyslogAppender">
    <syslogHost>fluentd</syslogHost>
    <port>5140</port>
    <suffixPattern>%logger{36} - %msg</suffixPattern>
    <protocol>UDP</protocol>
  </appender>
  <root level="INFO">
    <appender-ref ref="FLUENTD" />
  </root>
</configuration>
```

Configuración de Fluentd para recibir Syslog:

```xml
<source>
  @type syslog
  port 5140
  bind 0.0.0.0
  message_format rfc5424
  tag app.logs
</source>
```

> ℹ️ **Nota:** A diferencia del transporte TCP JSON (sección 7.1), el protocolo Syslog no transporta campos estructurados: el cuerpo del mensaje es texto plano. Esta diferencia es pedagógicamente relevante al comparar el nivel de observabilidad obtenido con cada protocolo.

---

## 📊 8. Visualización en Kibana

Una vez centralizados, los logs pueden ser explorados mediante Kibana, permitiendo:

- Búsqueda textual y estructurada.
- Filtros temporales.
- Identificación de patrones y anomalías.

Estas capacidades resultan especialmente relevantes en contextos educativos para ilustrar procesos de diagnóstico y análisis de fallos.

Accede a:

```
http://localhost:5601
```

**Discover:**

Navegue a **Hamburger menu → Discover**. Cree un data view con el patrón `logs-*` y campo de tiempo `@timestamp`. Esta vista muestra todos los índices generados por Fluentd con el prefijo `logs-YYYY.MM.dd`.

---

## 🧪 9. Actividades de profundización

- **Simular fallos y rastrear su origen:** El endpoint `GET /api/error` de la aplicación de ejemplo genera intencionalmente una `NullPointerException`. Ejecútelo y utilice Kibana para localizar el evento de error e inspeccionar el stacktrace estructurado.
- Comparar Fluentd y Logstash como componentes de procesamiento: ¿qué diferencias existen en su modelo de configuración y su ecosistema de plugins?
- Desplegar dos instancias de `logs.producer` y distinguirlas en Kibana por el campo `service.name`.
- Modificar `fluent.conf` para agregar un campo personalizado (ej. `environment: dev`) usando el plugin `record_transformer` y observar cómo se indexa en Elasticsearch.
- Analizar las implicaciones de usar índices con fecha (`logs-YYYY.MM.dd`) frente a data streams de Elasticsearch 9.x.

### Preguntas de verificación

1. En la configuración de Fluentd de esta guía, el bloque `<buffer>` usa `@type file` con `flush_interval 5s`. Explique qué papel cumple este buffer en términos de confiabilidad de entrega y qué ocurriría si el contenedor de Fluentd se reinicia antes de que el buffer se vacíe.
2. Compare el modelo de configuración de Fluentd (`fluent.conf` con directivas `<source>`, `<filter>`, `<match>`) frente al pipeline de Logstash (`input`, `filter`, `output`): ¿qué diferencias de diseño se observan en la forma de enrutar eventos a múltiples destinos?
3. La sección 7.2 describe el transporte Syslog UDP como alternativa al TCP JSON. Evalúe las implicaciones de observabilidad de cada protocolo: ¿cuál ofrece mayor fidelidad semántica y por qué el enfoque TCP JSON es preferible para sistemas modernos?

---

## 🛠️ 10. Troubleshooting

**Error común:** El contenedor `elasticsearch` se detiene inesperadamente o marca estado `Exit 78` / `Exit 137`.

**Solución:** Elasticsearch requiere configurar la memoria virtual del sistema anfitrión. En sistemas Linux o entornos WSL, ejecute el siguiente comando en la terminal de su máquina (fuera del contenedor) antes de iniciar `docker compose up -d`:
```bash
sudo sysctl -w vm.max_map_count=262144
```

---

**Error común:** Kibana muestra el mensaje *"Kibana cannot connect to the Elastic Package Registry"* al abrir la interfaz.

**Explicación:** Kibana 9.x intenta conectarse por defecto al registro externo de integraciones de Fleet. En un entorno de laboratorio local sin acceso a internet, este intento falla. El aviso es **no bloqueante**.

**Solución:** El archivo `docker-compose.yml` de esta guía ya incluye `xpack.fleet.enabled: "false"` en el servicio Kibana. Si crea su propio `docker-compose.yml`, asegúrese de incluir esa variable de entorno.

---

**Error común:** Fluentd no inicia y reporta `No such file or directory @ rb_sysopen - /fluentd/etc/fluent.conf`.

**Explicación:** El entrypoint del contenedor de Fluentd busca el archivo de configuración con el nombre exacto `fluent.conf` (no `fluentd.conf`).

**Solución:** Asegúrese de que el archivo de configuración se llame `fluent.conf`.

---

## 📚 Referencias

- Fluentd - https://docs.fluentd.org
- Fluentd (plugins) - https://www.fluentd.org/plugins
- fluent-plugin-elasticsearch - https://github.com/uken/fluent-plugin-elasticsearch
- Elasticsearch – https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
- Kibana – https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-kibana-with-docker

---

ℹ️ *Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
