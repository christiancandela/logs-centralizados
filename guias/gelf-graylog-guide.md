# **Centralización de Logs - ELK Stack**

---

## **Objetivo**
Configurar una arquitectura centralizada de logs usando **Docker Compose** con los siguientes componentes:
- **gelf** (Colector/Agregador de logs)
- **Elasticsearch** (Almacenamiento y búsqueda)
- **Graylog** (Visualización)

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
│       └── ecs.conf
└── .env (opcional, para variables)
```

---

## **3. Configuración de Contenedores**

### **a. `docker-compose.yml`**
```yaml
services:
   mongo:
      image: mongo:6.0
      container_name: mongo

   datanode:
      image: graylog/graylog-datanode:6.1
      hostname: "datanode"
      container_name: datanode
      environment:
         GRAYLOG_DATANODE_NODE_ID_FILE: "/var/lib/graylog-datanode/node-id"
         # GRAYLOG_DATANODE_PASSWORD_SECRET and GRAYLOG_PASSWORD_SECRET MUST be the same value
         GRAYLOG_DATANODE_PASSWORD_SECRET: "forpasswordencryption"
         GRAYLOG_DATANODE_MONGODB_URI: mongodb://mongo:27017/graylog
      ulimits:
         memlock:
            hard: -1
            soft: -1
         nofile:
            soft: 65536
            hard: 65536
      ports:
         - "8999:8999/tcp"   # DataNode API
         - "9200:9200/tcp"
         - "9300:9300/tcp"
      volumes:
         - "graylog-datanode:/var/lib/graylog-datanode"

   graylog:
      image: graylog/graylog:6.1
      container_name: graylog
      ports:
         - "9000:9000"
         - "12201:12201/udp"
         - "1514:1514"
      environment:
         # Configuración de MongoDB
         GRAYLOG_MONGODB_URI: mongodb://mongo:27017/graylog
         GRAYLOG_NODE_ID_FILE: "/usr/share/graylog/data/data/node-id"
         GRAYLOG_HTTP_EXTERNAL_URI: "http://127.0.0.1:9000/"
         # o se puede también GRAYLOG_HTTP_EXTERNAL_URI: "http://localhost:9000/"
         GRAYLOG_HTTP_BIND_ADDRESS: "0.0.0.0:9000"
         # CHANGE ME (must be at least 16 characters)!
         GRAYLOG_PASSWORD_SECRET: "forpasswordencryption"
         # Password: admin
         GRAYLOG_ROOT_PASSWORD_SHA2: "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918"
      volumes:
         - "graylog_data:/usr/share/graylog/data/data"
      depends_on:
         mongo:
            condition: "service_started"
         datanode:
            condition: "service_started"
      entrypoint: "/usr/bin/tini --  /docker-entrypoint.sh"

volumes:
   graylog-datanode:
   graylog_data:
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
datanode            Up                  8999/tpc, 9200/tcp, 9300/tcp
mongo               Up                  
graylog             Up                  1514/tcp, 9000/tcp, 12201/udp  
```

---

### **Paso 3: Configuración de graylog**

Acceda a la url de [graylog](http://localhost:9000) le pedirá un conjunto de credenciales que encontrara en el log del contenedor de graylog.
Siga las instrucciones de configuración. Cuando finalice y solicite nuevamente credenciales para acceder a la plataforma ingrese admin/admin.

---

### **Paso 4: Creación de la entrada de logs**

Puede crear la entrada de logs enviando la siguiente instrucción desde consola.

```bash
curl -H "Content-Type: application/json" -H "Authorization: Basic YWRtaW46YWRtaW4=" -H "X-Requested-By: curl" -X POST -v -d \
'{"title":"udp input","configuration":{"recv_buffer_size":262144,"bind_address":"0.0.0.0","port":12201,"decompress_size_limit":8388608},"type":"org.graylog2.inputs.gelf.udp.GELFUDPInput","global":true}' \
http://localhost:9000/api/system/inputs
```

O puede hacerlo desde la consola web de Graylog (System → Inputs → Seleccionar GELF UDP) dar clic en el botón Launch new input, configure los campos solicitados y finalice dando clic en Launch Input.

---

## **5. Configuración de Aplicaciones**

Cree una aplicación java que envíe sus logs a **graylog**

### **a. Para aplicaciones Quarkus**
En el caso de aplicaciones quarkus deberá adicionar:

- Crear su aplicación 

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.19.1:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer2 \
    -Dextensions='rest,logging-gelf' \
    -DnoCode
```

- Configure la aplicación en el **`logs.producer/src/main/resources/application.properties`** para que los logs sean enviados a logstash

```properties
quarkus.log.handler.gelf.enabled=true
quarkus.log.handler.gelf.host=localhost
quarkus.log.handler.gelf.port=12201
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
   <groupId>de.siegmar</groupId>
   <artifactId>logback-gelf</artifactId>
   <version>3.0.0</version> <!-- Verifica la última versión -->
</dependency>
```

Configura `logback.xml` para enviar logs a Logstash:
```xml
<configuration>
   <!-- Appender GELF UDP -->
   <appender name="GELF" class="de.siegmar.logbackgelf.GelfUdpAppender">
      <graylogHost>127.0.0.1</graylogHost> <!-- Reemplaza con la IP de tu servidor Graylog -->
      <graylogPort>12201</graylogPort> <!-- Puerto UDP de Graylog -->
      <maxChunkSize>508</maxChunkSize> <!-- Tamaño máximo de los mensajes fragmentados -->
      <useCompression>true</useCompression> <!-- Comprimir mensajes -->
      <layout class="de.siegmar.logbackgelf.GelfLayout">
         <originHost>mi_host</originHost> <!-- Nombre del host que envía los logs -->
         <includeRawMessage>false</includeRawMessage>
         <includeLevelName>true</includeLevelName>
      </layout>
   </appender>

   <!-- Logger principal -->
   <root level="info">
      <appender-ref ref="GELF" />
   </root>
</configuration>
```

---

## **6. Visualización en graylog**
1. Accede a Graylog:
   ```bash
   http://localhost:9000
   ```  
2. Ingrese a **Search** y ejecute la consulta, le mostrará por defecto los logs registrados:

---

## **7. Escalabilidad**
### **Para entornos productivos:**
- Implementar clusters para todos sus componentes y balanceadores de carga.
- Modifique las credenciales, haga uso de certificados digitales firmados y use el protocolo https.

---

## **8. Comandos Útiles**
| Comando                      | Descripción                  |
|------------------------------|------------------------------|
| `docker-compose logs -f`     | Ver logs en tiempo real      |
| `docker-compose down -v`     | Detener y eliminar volúmenes |
| `curl http://localhost:9000` | Verificar Graylog            |

---

## **Referencias**
- [graylog](https://graylog.org)
- [graylog doc](https://docs.graylog.org/docs/docker)

---

