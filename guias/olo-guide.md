# **Centralización de Logs - OLO Stack**

---

## **Objetivo**
Configurar una arquitectura centralizada de logs usando **Docker Compose** con los siguientes componentes:
- **logstash** (Colector/Agregador de logs)
- **Opensearch** (Almacenamiento y búsqueda)
- **Opensearch Dashboards** (Visualización)


---

## **1. Requisitos Previos**
✅ Docker instalado ([Guía de instalación](https://docs.docker.com/engine/install/))  
✅ Docker Compose ([Guía](https://docs.docker.com/compose/install/))  
✅ 4 GB de RAM mínimo (recomendado para Elasticsearch)

---

## **2. Estructura del Proyecto**
Crea la siguiente estructura de archivos:
```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer
│   ├── src/
│   └── pom.xml
├── logstash/
│   └── pipelines/
│       └── logstash.conf
└── .env (opcional, para variables)
```

---

## **3. Configuración de Contenedores**

### **a. `docker-compose.yml`**
```yaml
services:
   opensearch:
      image: opensearchproject/opensearch:3
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

   dashboards:
      image: opensearchproject/opensearch-dashboards:3
      container_name: dashboards
      environment:
         - OPENSEARCH_HOSTS=http://opensearch:9200
         - DISABLE_SECURITY_DASHBOARDS_PLUGIN=true
      ports:
         - "5601:5601"
      depends_on:
         - opensearch

   logstash:
      build: logstash
      container_name: logstash
      volumes:
         - ./logstash/pipelines:/usr/share/logstash/pipeline
      ports:
         - "4560:4560"
      depends_on:
         - opensearch
      environment:
         - xpack.monitoring.enabled=false

volumes:
   opensearch_data:
```

### **b. Dockerfile de logstash (`logstash/Dockerfile`)**
```Dockerfile
FROM docker.io/logstash:8.18.0
RUN logstash-plugin install logstash-output-opensearch
```

### **c. Configuración de logstash (`logstash/pipelines/logstash.conf`)**
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
  opensearch {
    hosts => ["http://opensearch:9200"]
    index => "logstash-%{+YYYY.MM.dd}"
  }
}
```

---

## **4. Despliegue**

### **Paso 1: Iniciar los servicios**
```bash
docker-compose up -d
```

### **Paso 2: Verificar contenedores**
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

### **Paso 3: Crear index-pattern en el dashboard**

El siguiente comando pretende crear un index-pattern en el Dashboard con el fin de poder visualizar los logs generados por logstash.

```shell
curl -XPOST "http://localhost:5601/api/saved_objects/index-pattern" \
  -H "Content-Type: application/json" \
  -H "osd-xsrf: true" \
  -d '{
    "attributes": {
      "title": "logstash-*",  
      "timeFieldName": "@timestamp"  
    }
  }'
```

---

## **5. Configuración de Aplicaciones**

Cree una aplicación java que envíe sus logs a **logstash**

### **a. Para aplicaciones Quarkus**
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

### **b. Para otras aplicaciones java**
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

## **6. Visualización en Opensearch Dashboard**
1. Accede a Opensearch Dashboard:
   ```bash
   http://localhost:5601
   ```  
2. Ingrese a **Opensearch Dashboard > Discover**: Allí podrá ver un registro de los logs. Alternativamente, también puede acceder a **Observability > Logs** y en el campo PPL ingresar `source = logstash-*`, esto le indica al sistema de donde deberá obtener los logs que se desean consultar. 

---

## **7. Escalabilidad**
### **Para entornos productivos:**
- Usa **Opensearch en cluster** (múltiples nodos).
- Active la autenticación para mejorar la seguridad del sistema.

---

## **8. Comandos Útiles**
| Comando                     | Descripción                          |
|-----------------------------|--------------------------------------|
| `docker-compose logs -f`    | Ver logs en tiempo real              |
| `docker-compose down -v`    | Detener y eliminar volúmenes         |
| `curl http://localhost:9200`| Verificar Elasticsearch              |

---

## **Referencias**
- [Logstash](https://www.elastic.co/docs/reference/logstash)
- [Opensearch](https://opensearch.org)
- [Opensearch Docker Guide](https://docs.opensearch.org/docs/latest/install-and-configure/install-opensearch/docker/)
- [Opensearch Dashboard Guide](https://docs.opensearch.org/docs/latest/dashboards/)
- [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html)
- [Opensearch Dashboard Query Language (DQL)](https://docs.opensearch.org/docs/latest/dashboards/dql/)
---

