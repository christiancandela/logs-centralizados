# 🧠 Centralización de Logs con ELK Stack

> *Guía práctica para implementar una solución de centralización de logs usando Docker Compose y el stack ELK, como componente clave de la observabilidad en arquitecturas de microservicios.*

---

## 🌟 Objetivo

Implementar una arquitectura básica de centralización de logs utilizando Docker Compose con los siguientes componentes:

- **Logstash**: Recolector y procesador de logs.
- **Elasticsearch**: Motor de almacenamiento y búsqueda.
- **Kibana**: Herramienta de visualización.

Esta guía está orientada a entornos de desarrollo, donde la **observabilidad** es esencial para depurar, entender y monitorear sistemas distribuidos.

---

## 🧩 1. Observabilidad y logs

En sistemas modernos basados en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a través de señales externas: **logs**, **métricas** y **trazas**. Dentro de estos pilares, los logs centralizados permiten:

- Realizar diagnósticos rápidos.
- Correlacionar eventos entre servicios.
- Detectar errores y comportamientos inesperados.
- Apoyar auditoría y análisis post-mortem.

El stack ELK es una de las soluciones más populares y extendidas para implementar esta funcionalidad.

---

## ⚙️ 2. Requisitos previos

✅ Docker instalado ([Guía de instalación](https://docs.docker.com/engine/install/))  
✅ Docker Compose ([Guía](https://docs.docker.com/compose/install/))  
✅ 4 GB de RAM (mínimo para ejecución fluida de Elasticsearch)

---

## 📂 3. Estructura del proyecto

Organiza tu proyecto con la siguiente estructura de archivos:

```
logs-centralizados/
├── docker-compose.yml
├── logs.producer/                 # Aplicación que genera logs
│   ├── src/
│   └── pom.xml
├── logstash/
│   └── pipelines/
│       └── ecs.conf               # Configuración de Logstash
└── .env                           # Opcional, para variables de entorno
```

📌 *Consejo:* Si trabajas en grupo, sube este proyecto a un repositorio GitHub para facilitar colaboración y revisión.

---

## 📊 4. Diagrama de arquitectura

```
[Aplicaciones Java/Quarkus] --- (TCP JSON) ---> [Logstash] ---> [Elasticsearch] ---> [Kibana]
                                               └────────── stdout
```

Este flujo representa cómo los eventos de log generados por las aplicaciones son enviados a Logstash, procesados y almacenados en Elasticsearch. Luego pueden ser visualizados en Kibana.

---

## 🛠️ 5. Configuración de Contenedores

### a. `docker-compose.yml`
```yaml
services:
  elasticsearch:
    image: docker.io/elasticsearch:8.18.0
    container_name: elasticsearch # Opcional
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false # Desactiva autenticación para desarrollo
      - cluster.routing.allocation.disk.threshold_enabled=false
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    volumes:
      - es_data:/usr/share/elasticsearch/data # Opcional en cuando se realizan pruebas de configuración
    ports:
      - "9200:9200"
      - "9300:9300"
    
  kibana:
    image: docker.io/kibana:8.18.0
    container_name: kibana # Opcional
    depends_on:
      - elasticsearch
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200 # Opcional, el valor por defecto de ELASTICSEARCH_HOSTS es http://elasticsearch:9200

  logstash:
    image: docker.io/logstash:8.18.0
    container_name: logstash # Opcional
    volumes:
      - source: ./logstash/pipelines
        target: /usr/share/logstash/pipeline
        type: bind
    ports:
      - "4560:4560"
    environment:
       - ELASTICSEARCH_HOSTS=http://elasticsearch:9200 # Opcional, el valor por defecto de ELASTICSEARCH_HOSTS es http://elasticsearch:9200
    depends_on:
      - elasticsearch


volumes:
  es_data:
```

### b. Configuración de logstash (`logstash/pipelines/ecs.conf`)
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
    mutate { rename => {"[mdc][traceId]" => "[trace][id]"} }
  }
}

output {
  stdout {}
  elasticsearch {
    hosts => [${ELASTICSEARCH_HOSTS:http://elasticsearch:9200}]
  }
}
```

---

## ▶️ 6. Despliegue y validación

### Paso 1: Iniciar los servicios
```bash
docker-compose up -d
```

### Paso 2: Verificar contenedores
```bash
docker-compose ps
```
Salida esperada:
```
NAME                STATUS              PORTS
elasticsearch       Up                  9200/tcp, 9300/tcp
kibana              Up                  5601/tcp
logstash            Up                  4560/tcp  
```

---

## 6. Configuración de Aplicaciones

Cree una aplicación java que envíe sus logs a **logstash**

### a. Para aplicaciones Quarkus
En el caso de aplicaciones quarkus deberá adicionar:

- Crear su aplicación 

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.19.1:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest' \
    -DnoCode
```

- Adicionar la siguiente dependencia en el archivo **`logs.producer/pom.xml`**.

```xml
<dependency>
   <groupId>io.quarkus</groupId>
   <artifactId>quarkus-logging-json</artifactId>
</dependency>
```

- Configure la aplicación en el **`logs.producer/src/main/resources/application.properties`** para que los logs sean enviados a logstash

```properties
# to keep the logs in the usual format in the console
quarkus.log.console.json=false

quarkus.log.socket.enable=true
quarkus.log.socket.json=true
# El valor de quarkus.log.socket.endpoint indica la url para el envío de logs 
quarkus.log.socket.endpoint=localhost:4560

# to have the exception serialized into a single text element
quarkus.log.socket.json.exception-output-type=formatted

# specify the format of the produced JSON log
quarkus.log.socket.json.log-format=ECS
```

- Para el registro de logs en su aplicación haga uso de la clase **`org.jboss.logging.Logger`** que puede ser inicializada o inyectada.

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

o

```java
@Inject
private final Logger log;
```

o

```java
private final Logger log;

@Inject
public MiClase(Logger log) {
   this.log = log;
}
```

o

```java
private final Logger log;

public MiClase(Logger log) {
   this.log = log;
}
```

> ℹ️ En quarkus es posible omitir la anotación **`@Inject`**

### b. Para otras aplicaciones java
Se puede hacer uso de librerías como Logback para el envío de los logs.

```xml
<dependency>
   <groupId>ch.qos.logback</groupId>
   <artifactId>logback-classic</artifactId>
   <version>1.5.18</version>
   <scope>compile</scope>
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
   
      <!-- Configuración del encoder para JSON -->
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
1. Accede a Kibana:
   ```bash
   http://localhost:5601
   ```  
2. Ingrese a **Observability > Logs > Logs Explorer**:

---

## 📚 9. Desafíos y buenas prácticas

### a. Desafíos guiados

- ✍️ Configura alertas en Kibana para eventos críticos
- 🔄 Simula caídas de servicio y rastrea su causa por logs
- 🔄 Compara ECS con un esquema personalizado
- Cambia la configuración del stack para implementar **Elasticsearch en cluster** (múltiples nodos).
- Añade autenticación con X-Pack.

### b. Buenas prácticas

- Usar logs estructurados
- Separar entornos (dev, test, prod)
- Configurar niveles de log (INFO, WARN, ERROR)


---

## **Referencias**
- [Logstash](https://www.elastic.co/docs/reference/logstash)
- [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html)
- [Kibana](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-kibana-with-docker)
- [KQL - Kibana Query Language](https://www.elastic.co/guide/en/kibana/current/kuery-query.html)
- [Elastic Common Schema (ECS)](https://www.elastic.co/guide/en/ecs/current/ecs-reference.html)

---

ℹ️ *Este recurso forma parte de una estrategia de fortalecimiento de la observabilidad en la asignatura "Arquitectura Orientada a Microservicios".*
