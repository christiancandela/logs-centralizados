# 🧠 Centralización de Logs con Promtail, Loki y Grafana (PLG Stack)

> *Guía práctica para implementar una solución de centralización de logs utilizando Docker Compose con el ecosistema de Grafana (Promtail y Loki), como instanciación de la arquitectura conceptual de observabilidad presentada en el documento central.*

---

## 🌟 Objetivo de la guía

Implementar y validar una arquitectura de centralización de logs mediante **Docker Compose**, utilizando **Promtail** como agente recolector, **Loki** como motor de indexación y almacenamiento, y **Grafana** para la visualización y análisis.

---

## 🎯 Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs basada en el ecosistema Grafana.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar aplicaciones para emitir logs estructurados hacia archivos.
- Configurar Promtail para recolectar y enviar (*scrape*) logs desde volúmenes compartidos.
- Analizar y correlacionar eventos centralizados utilizando el lenguaje LogQL en Grafana.

---

## 🧭 Propósito y alcance del recurso

El propósito principal de este recurso es guiar el diseño, despliegue y uso de una **arquitectura de centralización de logs** eficiente, basada en la filosofía de Loki (indexación ligera basada en etiquetas en lugar de texto completo).

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software y observabilidad.
- Un **entorno de laboratorio reproducible**, para experimentar con flujos de generación, recolección y análisis.
- Un **caso de estudio técnico**, que ilustra la recolección de logs a través de lectura directa de archivos (*file tailing*) utilizando Promtail.

---

## 🧩 1. Observabilidad y centralización de logs

En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema. Los **logs** constituyen una fuente primaria de información debido a su riqueza contextual.

El ecosistema de Grafana aborda la centralización con un enfoque muy eficiente:
- **Promtail** es el agente encargado de descubrir y leer archivos de log (o recibir streams) para enviarlos a Loki.
- **Loki** almacena los logs, pero solo indexa los metadatos (etiquetas/labels), lo que lo hace muy ligero comparado con motores de indexación completa como Elasticsearch o OpenSearch.

---

## ⚙️ 2. Requisitos previos

- Docker instalado (https://docs.docker.com/engine/install/)
- Docker Compose (https://docs.docker.com/compose/install/)
- Al menos **8 GB de RAM** libres.

---

## 📂 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
├── promtail/
│   └── promtail-config.yaml
└── logs/                 <-- Directorio compartido para logs
```

---

## 📊 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
         |
    (Escribe en archivo .log)
         v
  [Volumen Compartido]
         |
    (Lee archivo)
         v
     [Promtail]
         |
     (API HTTP)
         v
       [Loki] ---> [Grafana]
```

---

## 🛠️ 5. Implementación de la arquitectura conceptual

### 5.1 docker-compose.yml

```yaml
services:
  loki:
    image: grafana/loki:3.0.0
    container_name: loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml

  promtail:
    image: grafana/promtail:3.0.0
    container_name: promtail
    volumes:
      - ./logs:/var/log/app_logs
      - ./promtail/promtail-config.yaml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    depends_on:
      - loki

  grafana:
    image: grafana/grafana:11.0.0
    container_name: grafana
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
    ports:
      - "3000:3000"
    depends_on:
      - loki
```

### 5.2 Configuración de Promtail (`promtail-config.yaml`)

Cree un archivo llamado `promtail-config.yaml` dentro de la carpeta `promtail/`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
- job_name: java_apps
  static_configs:
  - targets:
      - localhost
    labels:
      job: quarkus_app
      environment: dev
      __path__: /var/log/app_logs/*.log
```

> **Nota:** Promtail está configurado para vigilar cualquier archivo `.log` dentro del directorio mapeado (`/var/log/app_logs/`).

---

## ▶️ 6. Despliegue y validación

Ejecute el entorno con:

```bash
docker-compose up -d
```

Verifique que los servicios estén activos:

```bash
docker-compose ps
```

---

## 🔌 7. Emisión de logs desde aplicaciones

A diferencia de otras guías donde se usa envío por red (TCP/UDP), Promtail se especializa en **leer archivos de log**. Configuraremos nuestras aplicaciones para escribir logs en la carpeta compartida `./logs`.

### 7.1 Aplicaciones Quarkus

Asegúrese de agregar el soporte para JSON y configurar Quarkus para escribir en archivo.

**Dependencia Maven:**
```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-logging-json</artifactId>
</dependency>
```

**`application.properties`**:
```properties
# Desactivamos JSON en consola (opcional)
quarkus.log.console.json=false

# Activamos el log en archivo con formato JSON
quarkus.log.file.enable=true
quarkus.log.file.json=true
quarkus.log.file.path=../logs/application.log
```
*(Asegúrese de que la ruta relativa coincida con el directorio `./logs` de su proyecto docker-compose).*

### 7.2 Otras aplicaciones Java (Logback)

Si usa Logback, configure un `FileAppender` con el codificador JSON de Logstash.

**Dependencias:**
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

**`logback.xml`**:
```xml
<configuration>
  <appender name="FILE" class="ch.qos.logback.core.FileAppender">
    <file>../logs/application.log</file>
    <encoder class="net.logstash.logback.encoder.LogstashEncoder" />
  </appender>

  <root level="INFO">
    <appender-ref ref="FILE" />
  </root>
</configuration>
```

---

## 📊 8. Visualización en Grafana

1. Acceda a Grafana en `http://localhost:3000`.
2. Como configuramos acceso anónimo como Administrador, entrará directo.
3. Vaya a **Connections -> Data sources** y agregue **Loki**.
   - URL: `http://loki:3100`
   - Clic en **Save & test**.
4. Vaya a **Explore** (menú izquierdo).
5. Seleccione Loki como fuente de datos.
6. En el campo "Label filters", seleccione `job` = `quarkus_app`.
7. Haga clic en **Run query** para ver los logs recolectados.

---

## 🧪 9. Actividades de profundización

- **Simular fallos y rastrear su origen:** Implemente un endpoint en la aplicación (ej. `GET /api/error`) que genere intencionalmente una excepción (`NullPointerException`). Utilice la pestaña Explore de Grafana y el lenguaje LogQL para buscar errores (`{job="quarkus_app"} |= "Exception"`).
- Analizar cómo Promtail maneja la lectura del archivo (*tailing*) y la rotación de logs.
- Comparar este enfoque basado en archivos contra enfoques de envío directo por red (TCP/UDP).

---

## 🛠️ 10. Troubleshooting

**Error común:** Grafana no logra conectarse a Loki.
**Solución:** Verifique en el archivo `docker-compose.yml` que Grafana y Loki compartan la misma red (o que se utilice el nombre de servicio correcto `http://loki:3100`). Asegúrese de que el contenedor de Loki esté en estado *Up* y no reiniciándose.

**Error común:** Promtail no envía los logs a Grafana.
**Solución:** Asegúrese de que su aplicación Java esté creando efectivamente el archivo en el directorio `./logs` de la máquina host, y que Promtail tenga los permisos de lectura sobre ese volumen montado.

---

## 📚 Referencias

- Loki Documentation: https://grafana.com/docs/loki/latest/
- Promtail Documentation: https://grafana.com/docs/loki/latest/send-data/promtail/
- LogQL (Loki Query Language): https://grafana.com/docs/loki/latest/query/
