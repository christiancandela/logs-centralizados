# **Centralización de Logs - ELK Stack**

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
- Al menos **4 GB de RAM** disponibles

---

## 📂 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
└── .env (opcional)
```

> ℹ️ La estructura de la aplicación de ejemplo (`logs.producer/`) es ilustrativa. Puede integrarse cualquier productor de logs Java/Quarkus.

---

## 📊 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
        |
        |   GELF (UDP)
        v
      [Graylog]
        |
        v
[Graylog DataNode]  (almacenamiento / indexación)
        ^
        |
     [MongoDB]  (metadatos/configuración)
```

La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- **GELF (Graylog Extended Log Format)** como formato/protocolo de envío (en este caso, **UDP**).
- **Graylog** como plataforma de ingestión, búsqueda y visualización.
- **MongoDB** para configuración y metadatos.
- **Graylog DataNode** (incluye el motor de almacenamiento/indexación requerido por Graylog en esta arquitectura).

El uso de **Docker Compose** permite describir y desplegar la arquitectura como código, garantizando la **portabilidad, reproducibilidad y facilidad de experimentación** del entorno, características fundamentales en un contexto formativo.

---

## 🛠️ 5. Implementación de la arquitectura conceptual con GELF y Graylog

### 5.1 docker-compose.yml

> ⚠️ Importante: conserve los valores y puertos indicados, ya que han sido usados como referencia en las configuraciones de envío y en la creación del input GELF.

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

## ▶️ 6. Despliegue y validación

### Inicialización de los servicios

El despliegue del entorno se realiza mediante un único comando, el cual levanta de forma coordinada todos los componentes definidos en el archivo `docker-compose.yml`.

```bash
docker-compose up -d
```

---

### Validación de los servicios

La validación del entorno permite comprobar que los contenedores asociados a MongoDB, DataNode y Graylog se encuentran en ejecución y disponibles.

```bash
docker-compose ps
```

Salida esperada (referencial):

```text
NAME      STATUS   PORTS
mongo     Up
datanode  Up       8999/tcp, 9200/tcp, 9300/tcp
graylog   Up       9000/tcp, 12201/udp, 1514/tcp
```

---

### Configuración inicial de Graylog

1. Accede a Graylog en:
   ```text
   http://localhost:9000
   ```
2. Graylog puede solicitar credenciales iniciales durante el asistente de configuración.  
   Una vez finalice, ingrese con:

- Usuario: `admin`
- Contraseña: `admin`

---

### Creación de la entrada GELF UDP (Input)

Graylog debe tener configurado un **input** para recibir mensajes GELF. Puede crearlo:

#### Opción A: Creación por API (recomendado para reproducibilidad)

```bash
curl -H "Content-Type: application/json" -H "Authorization: Basic YWRtaW46YWRtaW4=" -H "X-Requested-By: curl" -X POST -v -d \
'{"title":"udp input","configuration":{"recv_buffer_size":262144,"bind_address":"0.0.0.0","port":12201,"decompress_size_limit":8388608},"type":"org.graylog2.inputs.gelf.udp.GELFUDPInput","global":true}' \
http://localhost:9000/api/system/inputs
```

#### Opción B: Creación desde la consola web

- **System → Inputs**
- Seleccione **GELF UDP**
- Clic en **Launch new input**
- Configure el puerto **12201** y finalice con **Launch Input**

---

## 🔌 7. Emisión de logs desde aplicaciones

En esta sección se presentan dos rutas de integración:

- **Quarkus** con `logging-gelf`
- **Aplicaciones Java tradicionales** con Logback y `logback-gelf`

---

### 7.1 Aplicaciones Quarkus

#### Crear una aplicación (opcional)

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.19.1:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest,logging-gelf' \
    -DnoCode
```

#### Configurar envío GELF (`application.properties`)

> ℹ️ Este envío asume Graylog en `localhost` y el input GELF UDP escuchando en el puerto `12201`.

```properties
quarkus.log.handler.gelf.enabled=true
quarkus.log.handler.gelf.host=localhost
quarkus.log.handler.gelf.port=12201
```

#### Uso del logger

Para el registro de logs en su aplicación haga uso de la clase `org.jboss.logging.Logger`:

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

También puede ser inyectado (según el estilo de su proyecto):

```java
@Inject
Logger log;
```

> ℹ️ En Quarkus es posible omitir `@Inject` en ciertos escenarios de inyección.

---

### 7.2 Otras aplicaciones Java (Logback)

Para aplicaciones Java que no utilizan Quarkus, se puede enviar GELF mediante Logback.

#### Dependencia Maven

```xml
<dependency>
  <groupId>de.siegmar</groupId>
  <artifactId>logback-gelf</artifactId>
  <version>3.0.0</version>
</dependency>
```

#### Configuración de `logback.xml`

```xml
<configuration>
  <!-- Appender GELF UDP -->
  <appender name="GELF" class="de.siegmar.logbackgelf.GelfUdpAppender">
    <graylogHost>127.0.0.1</graylogHost>
    <graylogPort>12201</graylogPort>
    <maxChunkSize>508</maxChunkSize>
    <useCompression>true</useCompression>
    <layout class="de.siegmar.logbackgelf.GelfLayout">
      <originHost>mi_host</originHost>
      <includeRawMessage>false</includeRawMessage>
      <includeLevelName>true</includeLevelName>
    </layout>
  </appender>

  <root level="info">
    <appender-ref ref="GELF" />
  </root>
</configuration>
```

> ⚠️ En escenarios distintos a laboratorio, ajuste `graylogHost` al hostname/IP del servidor Graylog.

---

## 📊 8. Visualización en Graylog

Una vez centralizados, los logs pueden ser explorados mediante Graylog, permitiendo:

- Búsqueda textual y estructurada.
- Filtros temporales.
- Exploración por streams/inputs.
- Análisis rápido de eventos y contexto.

Accede a:

```text
http://localhost:9000
```

Ruta sugerida:

- **Search → All messages**

---

## 🧪 9. Actividades de profundización

- Simular fallos y rastrear su origen mediante logs centralizados.
- Comparar GELF UDP frente a envíos basados en TCP/HTTP (en términos de confiabilidad y pérdida de mensajes).
- Evaluar el impacto de **fragmentación** (`maxChunkSize`) en mensajes grandes.
- Implementar múltiples productores de logs y distinguirlos por campos como `originHost` o metadatos del evento.
- Analizar consideraciones de seguridad (TLS, autenticación, control de acceso) para escenarios productivos.

---

## 📚 Referencias

- Graylog – https://graylog.org
- Graylog Docs (Docker) – https://docs.graylog.org/docs/docker
- GELF (Getting in logs) – https://go2docs.graylog.org/current/getting_in_log_data/gelf.html

---

ℹ️ *Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
