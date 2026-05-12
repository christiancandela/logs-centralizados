# 🧠 Pipeline de Observabilidad con Vector, Loki y Grafana

> *Guía práctica para implementar una solución de centralización de logs de alto rendimiento utilizando Vector como enrutador y transformador, conectado a Loki y Grafana.*

---

## 🌟 Objetivo de la guía

Implementar y validar una arquitectura moderna de enrutamiento de logs utilizando **Vector** (una herramienta ultra-rápida escrita en Rust) como reemplazo ligero a componentes pesados como Logstash o Fluentd, y conectarlo con **Loki** para el almacenamiento eficiente.

---

## 🎯 Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Entender el concepto de *Pipeline de Observabilidad* y su importancia para el rendimiento.
- Desplegar **Vector** como agregador y enrutador de logs.
- Configurar transformaciones y análisis (*parsing*) de eventos directamente en memoria utilizando *Vector Remap Language (VRL)*.
- Correlacionar eventos en Grafana provenientes de una arquitectura heterogénea.

---

## 🧭 Propósito y alcance del recurso

Esta guía aborda el "estado del arte" en el enrutamiento y procesamiento de telemetría. **Vector** está diseñado para ser hasta 10 veces más rápido que alternativas basadas en Java (Logstash) o Ruby (Fluentd), utilizando una fracción de los recursos de CPU y RAM.

El alcance del recurso se centra en:
- La recolección de logs estructurados (JSON) vía TCP.
- Su transformación ligera.
- El envío hacia un motor de indexación de etiquetas (Loki).

---

## 🧩 1. Observabilidad y rendimiento con Vector

En arquitecturas donde el volumen de logs es masivo (miles de eventos por segundo), el componente de recolección y procesamiento suele convertirse en el cuello de botella. 
**Vector** soluciona esto al ser un ejecutable nativo compilado (Rust) que consume mínimos recursos. Actúa como una "navaja suiza", permitiendo recolectar desde múltiples fuentes (Syslog, Docker, archivos, TCP), transformar la data al vuelo (enriquecimiento, censura de datos sensibles) y enrutarla hacia múltiples destinos (Loki, Elasticsearch, S3, etc.).

---

## ⚙️ 2. Requisitos previos

- Docker instalado y Docker Compose.
- Al menos **8 GB de RAM** libres (aunque Vector es ligero, Loki y Grafana requieren recursos).

---

## 📂 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
└── vector/
    └── vector.toml
```

---

## 📊 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
         |
     (TCP JSON)
         v
      [Vector]  <-- Parseo y Enrutamiento (VRL)
         |
     (HTTP API)
         v
       [Loki] ---> [Grafana]
```

---

## 🛠️ 5. Implementación de la arquitectura conceptual

### 5.1 docker-compose.yml

```yaml
services:
  vector:
    image: timberio/vector:0.38.0-alpine
    container_name: vector
    volumes:
      - ./vector/vector.toml:/etc/vector/vector.toml:ro
    ports:
      - "4560:4560" # Puerto TCP para recibir logs de la app
    depends_on:
      - loki

  loki:
    image: grafana/loki:3.0.0
    container_name: loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml

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

### 5.2 Configuración de Vector (`vector.toml`)

Cree un archivo llamado `vector.toml` dentro de la carpeta `vector/`. Este archivo utiliza el lenguaje de Vector para definir el Pipeline (*Source -> Transform -> Sink*).

```toml
# 1. ORIGEN: Recibe logs en JSON por TCP
[sources.java_app]
type = "socket"
address = "0.0.0.0:4560"
mode = "tcp"

# 2. TRANSFORMACIÓN: Intenta parsear el mensaje crudo como JSON
[transforms.parse_json]
type = "remap"
inputs = ["java_app"]
source = '''
  # VRL (Vector Remap Language)
  parsed, err = parse_json(.message)
  if err == null {
    . = merge(., parsed)
  }
'''

# 3. DESTINO: Envía los logs procesados a Loki
[sinks.loki_out]
type = "loki"
inputs = ["parse_json"]
endpoint = "http://loki:3100"
encoding.codec = "json"
  
  [sinks.loki_out.labels]
  job = "vector_app_logs"
  source = "java_service"
```

---

## ▶️ 6. Despliegue y validación

```bash
docker-compose up -d
```

Verifique los servicios:
```bash
docker-compose ps
```

---

## 🔌 7. Emisión de logs desde aplicaciones

Configuraremos la aplicación para enviar logs estructurados directamente al socket TCP de Vector, emulando el mismo comportamiento que se usaría con Logstash, pero aprovechando el altísimo rendimiento de Vector.

### 7.1 Aplicaciones Quarkus

**Dependencia Maven:**
```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-logging-json</artifactId>
</dependency>
```

**`application.properties`**:
```properties
quarkus.log.console.json=false
quarkus.log.socket.enable=true
quarkus.log.socket.json=true
# Apuntamos a Vector en el puerto 4560
quarkus.log.socket.endpoint=localhost:4560
quarkus.log.socket.json.log-format=ECS
```

### 7.2 Otras aplicaciones Java (Logback)

Si usa Logback tradicional, utilice el `LogstashTcpSocketAppender`, el cual es 100% compatible con la entrada de Socket de Vector.

```xml
<appender name="VECTOR" class="net.logstash.logback.appender.LogstashTcpSocketAppender">
  <destination>localhost:4560</destination>
  <encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <customFields>{"appname":"mi-app-java"}</customFields>
  </encoder>
</appender>

<root level="INFO">
  <appender-ref ref="VECTOR" />
</root>
```

---

## 📊 8. Visualización en Grafana

1. Acceda a Grafana en `http://localhost:3000`.
2. Vaya a **Connections -> Data sources** y agregue **Loki** apuntando a `http://loki:3100`.
3. Vaya a **Explore**.
4. Seleccione Loki.
5. Busque utilizando las etiquetas inyectadas por Vector: `{job="vector_app_logs"}`.

---

## 🧪 9. Actividades de profundización

- **Simular fallos y rastrear su origen:** Implemente un endpoint en la aplicación (ej. `GET /api/error`) que genere una excepción (`NullPointerException`). Observe en Grafana la estructura del evento y cómo Vector ha preservado los campos anidados al parsear el JSON original.
- **Enriquecimiento al vuelo:** Modifique la sección `transforms` en `vector.toml` para inyectar una nueva variable estática o eliminar ("censurar") un campo específico del log (ej. ocultar información sensible) usando *VRL* antes de que llegue a Loki.
- Analice el uso de memoria RAM del contenedor `vector` usando `docker stats` y compárelo mentalmente con los despliegues de Logstash de las primeras guías.

---

## 🛠️ 10. Troubleshooting

**Error común:** Vector rechaza la conexión de la aplicación o se pierden logs.
**Solución:** Revise que el puerto `4560` esté mapeado correctamente en `docker-compose.yml`. Si la aplicación usa otro formato que no es JSON, la regla de transformación `parse_json` fallará en VRL, aunque el log igualmente llegará a Loki pero en texto plano.

---

## 📚 Referencias

- Vector Documentation: https://vector.dev/docs/
- Vector Remap Language (VRL): https://vector.dev/docs/reference/vrl/
- Loki Integrations: https://grafana.com/docs/loki/latest/send-data/vector/

---
