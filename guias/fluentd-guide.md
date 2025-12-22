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
- Al menos **4 GB de RAM** disponibles

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
│       └── fluentd.conf
└── .env
```

---

## 📊 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
        |
        | (Syslog / UDP)
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
  elasticsearch:
    image: docker.io/elasticsearch:8.18.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - cluster.routing.allocation.disk.threshold_enabled=false
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    ports:
      - "9200:9200"
      - "9300:9300"

  kibana:
    image: docker.io/kibana:8.18.0
    container_name: kibana
    depends_on:
      - elasticsearch
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200

  fluentd:
    build: ./fluentd
    container_name: fluentd
    volumes:
      - ./fluentd/conf:/fluentd/etc
    ports:
      - "24224:24224"
      - "5140:5140/udp"
    environment:
       - ELASTICSEARCH_HOST=elasticsearch
       - ELASTICSEARCH_PORT=9200 
    depends_on:
      - elasticsearch

volumes:
  es_data:
```

---

### 5.2 Configuración de Fluentd (`fluentd.conf`)

```xml
<source>
  @type syslog
  port 5140
  bind 0.0.0.0
  message_format rfc5424
  tag app.logs
</source>

<filter app.logs.**>
  @type record_transformer
  enable_ruby true
  remove_keys ident
  <record>
    service.name ${record.has_key?('ident') ? record['ident'] : 'app-unknow'}
    data_stream.type logs
    data_stream {"namespace" : "default", "type" : "logs", "dataset" : "generic"}
  </record>
</filter>

<match app.logs.**>
  @type elasticsearch
  host "#{ENV['ELASTICSEARCH_HOST'] || 'elasticsearch'}"
  port "#{ENV['ELASTICSEARCH_PORT'] || 9200}"
  logstash_format true
  logstash_prefix logs
  <buffer>
    @type file
    path /var/log/fluentd/buffers/quarkus
    flush_interval 5s
  </buffer>
</match>
```

---

### 5.3 Dockerfile de Fluentd

```dockerfile
FROM fluent/fluentd:v1.18.0-debian
RUN gem install fluent-plugin-elasticsearch
```

---

## ▶️ 6. Despliegue y validación

### Inicialización de los servicios

El despliegue del entorno se realiza mediante un único comando, el cual levanta de forma coordinada todos los componentes definidos en el archivo `docker-compose.yml`.

```bash
docker-compose up -d
```

### Validación de los servicios

La validación del entorno permite comprobar que los contenedores asociados a Elasticsearch, Fluentd y Kibana se encuentran en ejecución y disponibles.

```bash
docker-compose ps
```

---

### Persistencia y configuración del entorno

Se emplean **volúmenes Docker** para garantizar la persistencia de los datos almacenados en **Elasticsearch**, incluso ante reinicios del entorno.

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
  <artifactId>quarkus-logging-json</artifactId>
</dependency>
```

- Configure su aplicación para que los logs sean enviados a fluentd. (**`application.properties`**)

```properties
quarkus.log.console.json=false
quarkus.log.syslog.enable=true
quarkus.log.syslog.endpoint=localhost:5140
quarkus.log.syslog.protocol=udp
quarkus.log.syslog.app-name=logs.producer
quarkus.log.syslog.hostname=${HOSTNAME}
```

**Uso del logger:**

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

### 7.2 Otras aplicaciones Java (Logback)

Para otras aplicaciones Java que no utilizan Quarkus, el recurso presenta un ejemplo basado en **Fluentd**, empleando un *encoder* compatible con Fluentd para la generación de logs estructurados en formato JSON.

Este enfoque permite ilustrar cómo aplicaciones Java tradicionales pueden integrarse a una arquitectura de centralización de logs, resaltando la importancia de la estructuración y consistencia de los eventos generados.

```xml
<dependency>
   <groupId>ch.qos.logback</groupId>
   <artifactId>logback-classic</artifactId>
   <version>1.5.18</version>
   <scope>compile</scope>
</dependency>
```

Configura `logback.xml` para enviar logs a Logstash:

```xml
<configuration>
  <appender name="FLUENTD" class="ch.qos.logback.classic.net.SyslogAppender">
    <remoteHost>fluentd</remoteHost>
    <port>5140</port>
    <suffixPattern>%logger{36} - %msg</suffixPattern>
    <protocol>UDP</protocol> 
  </appender>
  <root level="INFO">
    <appender-ref ref="FLUENTD" />
  </root>
</configuration>
```

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

Ruta sugerida:

**Observability → Logs → Logs Explorer**

---

## 🧪 9. Actividades de profundización

- Comparar Fluentd y Logstash como componentes de procesamiento.
- Modificar filtros para enriquecer eventos.
- Simular múltiples productores de logs.
- Analizar implicaciones del uso de UDP.

---

## 📚 Referencias

- Fluentd - https://docs.fluentd.org
- Fluentd (plugins) - https://www.fluentd.org/plugins
- Elasticsearch – https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
- Kibana – https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-kibana-with-docker

---

ℹ️ *Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
