# **Centralización de Logs - ELK Stack**

---

## **Objetivo**
Configurar una arquitectura centralizada de logs usando **Docker Compose** con los siguientes componentes:
- **fluentd** (Colector/Agregador de logs)
- **Elasticsearch** (Almacenamiento y búsqueda)
- **Kibana** (Visualización)


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
├── fluentd/
│   ├── Dockerfile
│   └── conf/
│       └── fluentd.conf
└── .env (opcional, para variables)
```

---

## **3. Configuración de Contenedores**

### **a. `docker-compose.yml`**
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

  fluentd:
     build: ./fluentd
     container_name: fluentd # Opcional
     volumes:
        - ./fluentd/conf:/fluentd/etc
     ports:
        - "24224:24224"
        - "5140:5140/udp"
     depends_on:
        - elasticsearch


volumes:
  es_data:
```

### **b. Configuración de fluentd (`fluentd/conf/fluentd.conf`)**
```xml
<source>
   @type syslog
   port 5140
   bind 0.0.0.0
   message_format rfc5424
   tag app.logs
</source>

# (Opcional) Filtro para enriquecer los logs
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

# Envío a Elasticsearch (con buffer para evitar pérdidas)
<match app.logs.**>
  @type elasticsearch
  host elasticsearch
  port 9200
  logstash_format true
  logstash_prefix logs
   <buffer>
      @type file
      path /var/log/fluentd/buffers/quarkus
      flush_interval 5s
   </buffer>
</match>
```

### **c. Dockerfile de fluentd (`fluentd/Dockerfile`)**
```dockerfile
FROM fluent/fluentd:v1.18.0-debian
RUN gem install fluent-plugin-elasticsearch
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
fluentd             Up                  5140/udp  
```

---

## **5. Configuración de Aplicaciones**

Cree una aplicación java que envíe sus logs a **fluentd**

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
quarkus.log.console.json=false
quarkus.log.syslog.enable=true
quarkus.log.syslog.endpoint=localhost:5140
quarkus.log.syslog.protocol=udp
quarkus.log.syslog.app-name=logs.producer
quarkus.log.syslog.hostname=${HOSTNAME}
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
```

Configura `logback.xml` para enviar logs a Logstash:
```xml
<appender name="FLUENTD" class="ch.qos.logback.classic.net.SyslogAppender">
  <remoteHost>fluentd</remoteHost>
  <port>5140</port>
  <suffixPattern>%logger{36} - %msg</suffixPattern>
  <protocol>UDP</protocol> 
</appender>
<root level="INFO">
<appender-ref ref="FLUENTD" />
</root>
```

---

## **6. Visualización en Kibana**
1. Accede a Kibana:
   ```bash
   http://localhost:5601
   ```  
2. Ingrese a **Observability > Logs > Logs Explorer**:

---

## **7. Escalabilidad**
### **Para entornos productivos:**
- Usa **Elasticsearch en cluster** (múltiples nodos).
- Añade autenticación con X-Pack.

---

## **8. Comandos Útiles**
| Comando                     | Descripción                          |
|-----------------------------|--------------------------------------|
| `docker-compose logs -f`    | Ver logs en tiempo real              |
| `docker-compose down -v`    | Detener y eliminar volúmenes         |
| `curl http://localhost:9200`| Verificar Elasticsearch              |

---

## **Referencias**
- [Fluentd Plugins](https://www.fluentd.org/plugins)
- [Fluentd Documentation](https://docs.fluentd.org)
- [Fluentd Guides](https://www.fluentd.org/guides)
- [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html)
- [Kibana](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-kibana-with-docker)
- [Kibana Query Language (KQL)](https://www.elastic.co/guide/en/kibana/current/kuery-query.html)

---

