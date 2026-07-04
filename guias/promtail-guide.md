# Centralización de Logs con Promtail, Loki y Grafana (PLG Stack)

> *Guía práctica para implementar una solución de centralización de logs utilizando Docker Compose con el ecosistema de Grafana (Promtail y Loki), como instanciación de la arquitectura conceptual de observabilidad presentada en el documento central.*

> **Estado de Promtail:** A partir de 2023, Grafana Labs ha puesto Promtail en **modo mantenimiento**. Se siguen publicando correcciones de seguridad, pero no se añaden nuevas funcionalidades. La versión `3.0.0` es la última de la rama principal y no se prevén versiones posteriores. La herramienta recomendada para nuevos proyectos es [**Grafana Alloy**](https://grafana.com/docs/alloy/), el sucesor unificado que incorpora las capacidades de Promtail y del Grafana Agent. Esta guía usa Promtail porque su modelo conceptual (*file tailing* hacia Loki) es más directo para el aprendizaje y sigue siendo completamente funcional. Una vez comprendido Promtail, la migración a Alloy es natural.

## Objetivo de la guía

Implementar y validar una arquitectura de centralización de logs mediante **Docker Compose**, utilizando **Promtail** como agente recolector, **Loki** como motor de indexación y almacenamiento, y **Grafana** para la visualización y análisis.

## Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs basada en el ecosistema Grafana.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar aplicaciones para emitir logs estructurados hacia archivos.
- Configurar Promtail para recolectar y enviar (*scrape*) logs desde volúmenes compartidos.
- Analizar y correlacionar eventos centralizados utilizando el lenguaje LogQL en Grafana.

**Tiempo estimado:** 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

**Evidencias esperadas:** al finalizar la guía, el estudiante debe contar con (a) el archivo `docker-compose.yml` y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en Grafana que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script `smoke_test.sh` de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

## Propósito y alcance del recurso

El propósito principal de este recurso es guiar el diseño, despliegue y uso de una **arquitectura de centralización de logs** eficiente, basada en la filosofía de Loki (indexación ligera basada en etiquetas en lugar de texto completo).

El material está concebido como:

- Un **recurso educativo aplicado**, orientado a cursos de arquitectura de software y observabilidad.
- Un **entorno de laboratorio reproducible**, para experimentar con flujos de generación, recolección y análisis.
- Un **caso de estudio técnico**, que ilustra la recolección de logs a través de lectura directa de archivos (*file tailing*) utilizando Promtail.

## 1. Observabilidad y centralización de logs

En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de señales externas. Los **logs** constituyen una fuente primaria de información debido a su riqueza contextual.

Si las guías de ELK y OLO te mostraron el paradigma del índice invertido, esta guía te presenta su contrapunto más interesante. El ecosistema de Grafana (Promtail y Loki) parte de una pregunta provocadora: *¿y si no indexáramos el contenido de los logs en absoluto?*

### El paradigma de Loki: indexar solo etiquetas

Recordando los tres paradigmas de almacenamiento del marco conceptual (§5.7.3), Loki encarna el tercero: el **índice de solo etiquetas**. La diferencia con ELK es radical y vale la pena detenerse en ella:

| | ELK / OpenSearch | Loki |
|---|---|---|
| Qué indexa | Cada término de cada mensaje | Solo un puñado de etiquetas (metadatos) |
| Buscar texto libre | Inmediato (índice invertido) | Escaneo en tiempo de consulta |
| Costo de almacenamiento | Alto | Muy bajo |
| Analogía | El índice temático de un libro | Las etiquetas de las carpetas de un archivador |

¿Por qué renunciar a indexar el contenido? Porque indexarlo todo es caro (marco conceptual, §5.7.3). La apuesta de Loki es que, en la práctica, casi siempre acotas tu búsqueda primero por metadatos ("dame los logs del servicio `pagos` en el entorno `prod` durante la última hora") y solo entonces buscas dentro de ese subconjunto ya reducido. Loki indexa esas etiquetas (`servicio`, `entorno`...) para filtrar a gran velocidad, y deja el contenido sin indexar, comprimido en bloques baratos que solo se escanean cuando hace falta.

El resultado es un sistema mucho más ligero en disco y memoria que un motor de indexación completa, a cambio de búsquedas de texto libre más lentas. De nuevo: no es "mejor" ni "peor", es un compromiso distinto.

El stack PLG (Promtail, Loki, Grafana) se reparte las etapas conceptuales de esta forma:

| Componente | Etapa conceptual | Rol |
|---|---|---|
| **Promtail** | Recolección | Descubre y lee archivos de log (*file tailing*) y los envía a Loki |
| **Loki** | Almacenamiento + Búsqueda | Indexa solo etiquetas; responde consultas mediante **LogQL** |
| **Grafana** | Visualización | Explora y grafica los logs con LogQL |

> [!NOTE]
> El diseño cuidadoso de las etiquetas es crítico en Loki: usar como etiqueta un campo de alta **cardinalidad** (marco conceptual, §5.6), como un identificador de usuario, multiplica el número de flujos internos y degrada el rendimiento. La regla práctica es: etiquetas de baja cardinalidad, y el resto de la información dentro del mensaje.

## 2. Requisitos previos

- Docker instalado (https://docs.docker.com/engine/install/)
- Docker Compose (https://docs.docker.com/compose/install/)
- Al menos **8 GB de RAM** libres.

### Dimensionamiento de recursos

**Consumo estimado del stack:** ~2.5 GB de RAM en estado estable. Se trata de un stack ligero (la indexación de Loki se basa solo en etiquetas), apto incluso para equipos con 4 GB de RAM.

Cada servicio declara un `mem_limit` en el `docker-compose.yml` para acotar su consumo de memoria:

| Servicio | Función en el pipeline | `mem_limit` por defecto |
|----------|------------------------|-------------------------|
| `logs.producer` | Aplicación Quarkus productora de logs | `512m` |
| `loki` | Motor de indexación (solo labels) y almacenamiento | `512m` |
| `promtail` | Agente recolector (*file tailing*) | `256m` |
| `grafana` | Visualización y consulta (LogQL) | `512m` |

Estos valores son parametrizables mediante variables de entorno definidas en un archivo `.env` junto al `docker-compose.yml`, lo que permite ajustarlos sin modificar el compose:

```bash
LOKI_MEM_LIMIT=512m
PROMTAIL_MEM_LIMIT=256m
GRAFANA_MEM_LIMIT=512m
PRODUCER_MEM_LIMIT=512m
```

## 3. Estructura del proyecto

```bash
logs-centralizados/
├── docker-compose.yml
├── logs.producer/
│   ├── src/
│   └── pom.xml
├── promtail/
│   └── promtail-config.yaml
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── loki.yaml
└── logs/                 <-- Volumen compartido para archivos de log
```

## 4. Arquitectura de la solución

```text
[Aplicaciones Java / Quarkus]
         |
    (Escribe en archivo .log)
         v
  [Volumen Compartido ./logs]
         |
    (Lee archivo / tailing)
         v
     [Promtail]
         |
     (API HTTP push)
         v
       [Loki] ---> [Grafana]
```

La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- **Promtail**: agente de recolección que vigila (*tail*) archivos de log en un volumen compartido y los envía a Loki.
- **Loki**: motor de almacenamiento ligero que indexa solo etiquetas (labels), no el contenido textual de los logs.
- **Grafana**: capa de visualización y exploración mediante el lenguaje de consulta **LogQL**.

## 5. Implementación de la arquitectura conceptual

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
    volumes:
      - ./logs:/deployments/logs

  loki:
    image: grafana/loki:3.0.0
    container_name: loki
    mem_limit: ${LOKI_MEM_LIMIT:-512m}
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:3100/ready || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 15s

  promtail:
    image: grafana/promtail:3.0.0
    container_name: promtail
    mem_limit: ${PROMTAIL_MEM_LIMIT:-256m}
    volumes:
      - ./logs:/var/log/app_logs:ro
      - source: ./promtail/promtail-config.yaml
        target: /etc/promtail/config.yml
        type: bind
    command: -config.file=/etc/promtail/config.yml
    depends_on:
      loki:
        condition: service_healthy

  grafana:
    image: grafana/grafana:13.0.1
    container_name: grafana
    mem_limit: ${GRAFANA_MEM_LIMIT:-512m}
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
    ports:
      - "3000:3000"
    volumes:
      - source: ./grafana/provisioning
        target: /etc/grafana/provisioning
        type: bind
    depends_on:
      loki:
        condition: service_healthy
```

> [!NOTE]
> La carpeta `./logs` actúa como volumen compartido: `logs.producer` escribe los archivos allí y Promtail los lee en modo solo lectura (`:ro`). La carpeta `./grafana/provisioning` configura automáticamente Loki como fuente de datos en Grafana.

### 5.2 Configuración de Promtail (`promtail-config.yaml`)

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
    pipeline_stages:
      - regex:
          expression: '"log\.level":"(?P<level>[^"]+)"'
      - labels:
          level:
```

> [!NOTE]
> La etapa `regex` extrae el campo `log.level` del JSON de cada línea y lo convierte en un **label de Loki** (`level`). Esto permite filtrar logs por nivel directamente en LogQL sin necesidad de analizar el contenido. Las claves con punto (como `log.level`) no pueden ser extraídas con la etapa `json` estándar de Promtail porque gjson las interpreta como rutas anidadas; el enfoque `regex` resuelve este caso.

### 5.3 Aprovisionamiento de Grafana (`grafana/provisioning/datasources/loki.yaml`)

```yaml
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
```

> [!NOTE]
> Este archivo configura Loki como fuente de datos de Grafana automáticamente al arrancar el contenedor. No es necesario agregarla manualmente desde la interfaz.

## 6. Despliegue y validación

Antes de levantar el stack, cree el directorio compartido para los logs:

```bash
mkdir -p logs
```

Luego ejecute:

```bash
docker compose up -d
```

Verifique que los servicios estén activos:

```bash
docker compose ps
```

## 7. Emisión de logs desde aplicaciones

A diferencia de otras guías donde se usa envío por red (TCP/UDP), Promtail se especializa en **leer archivos de log**. La aplicación escribe en un archivo dentro del volumen compartido `./logs`, y Promtail lo vigila continuamente.

### 7.1 Aplicaciones Quarkus

- En caso de no tener una aplicación puede crear con el siguiente comando.

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest,logging-json' \
    -DnoCode
```

- Configure su aplicación para escribir logs en formato JSON al archivo compartido. (**`application.properties`**)

```properties
quarkus.log.console.json=false

# Escribir logs estructurados en formato JSON al archivo compartido con Promtail
quarkus.log.file.enable=true
quarkus.log.file.json=true
quarkus.log.file.path=/deployments/logs/application.log
quarkus.log.file.json.exception-output-type=formatted
quarkus.log.file.json.log-format=ECS
```

> [!NOTE]
> La ruta `/deployments/logs/application.log` es la ruta **dentro del contenedor**. El `docker-compose.yml` monta `./logs` en `/deployments/logs`, por lo que el archivo quedará disponible en `./logs/application.log` en el host.

**Uso del logger:**

```java
private static final Logger LOG = Logger.getLogger(MiClase.class);
```

### 7.2 Otras aplicaciones Java (Logback)

Si usa Logback, configure un `FileAppender` con el codificador JSON de Logstash.

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

`logback.xml`:

```xml
<configuration>
  <appender name="FILE" class="ch.qos.logback.core.FileAppender">
    <file>/deployments/logs/application.log</file>
    <encoder class="net.logstash.logback.encoder.LogstashEncoder" />
  </appender>

  <root level="INFO">
    <appender-ref ref="FILE" />
  </root>
</configuration>
```

## 8. Visualización en Grafana

Acceda a Grafana en `http://localhost:3000`. La fuente de datos Loki ya está preconfigurada.

Navegue a **Explore** (icono de brújula en el menú izquierdo) y seleccione **Loki** como fuente de datos.

**Consultas LogQL de ejemplo:**

Todos los logs de la aplicación:
```logql
{job="quarkus_app"}
```

Filtrar por nivel:
```logql
{job="quarkus_app", level="ERROR"}
```

Buscar errores por contenido:
```logql
{job="quarkus_app"} |= "NullPointerException"
```

Analizar los campos del JSON y mostrar solo el mensaje:
```logql
{job="quarkus_app"} | json | line_format "{{.message}}"
```

## 9. Actividades de profundización

- **Simular fallos y rastrear su origen:** El endpoint `GET /api/error` genera intencionalmente una `NullPointerException`. Ejecútelo y utilice la consulta LogQL `{job="quarkus_app"} |= "NullPointerException"` para localizarlo en Grafana.
- Analizar cómo Promtail maneja la lectura del archivo (*tailing*) y la posición de lectura (archivo `positions.yaml`).
- Comparar el enfoque basado en archivos contra el envío directo por red (TCP/UDP): ¿qué ventajas y desventajas ofrece cada uno en términos de acoplamiento, confiabilidad y rendimiento?
- Desplegar dos instancias de `logs.producer` escribiendo en archivos distintos y distinguirlas mediante labels de Promtail.
- Analizar las implicaciones del modelo de indexación de Loki (solo labels) frente a la indexación completa de Elasticsearch.

### Cuestionario de análisis crítico

1. La configuración de Promtail usa una etapa `regex` para extraer `log.level` como label de Loki. Explique por qué no se puede usar la etapa `json` estándar para esta tarea con el formato ECS de Quarkus.
2. Analice el mecanismo de *file tailing* de Promtail y el archivo `positions.yaml`: ¿qué garantías de entrega ofrece este enfoque si el contenedor de Promtail se reinicia inesperadamente? ¿Es equivalente al buffer de Fluentd o al TCP de Logstash?
3. Loki indexa solo etiquetas (labels) y no el contenido textual de los logs. Evalúe las ventajas e inconvenientes de este diseño frente a la indexación completa de Elasticsearch: ¿qué tipos de consultas se vuelven más costosas con Loki y cuáles se benefician de su ligereza?

## 10. Troubleshooting

**Error común:** El archivo `./logs/application.log` no se crea.

**Solución:** Verifique que el directorio `./logs` exista en el host antes de ejecutar `docker compose up`. El contenedor `logs.producer` escribe en `/deployments/logs/` que debe estar montado correctamente. Cree el directorio con `mkdir -p logs`.

---

**Error común:** Grafana no muestra datos al consultar en Explore.

**Solución:** Verifique que Promtail esté enviando logs con `docker compose logs promtail`. Asegúrese de que el archivo de log exista en `./logs/` y que Loki esté saludable (`docker compose ps`). Confirme que la URL de la datasource en Grafana sea `http://loki:3100`.

---

**Error común:** Loki devuelve error al iniciar por permisos en `/tmp/loki`.

**Solución:** Loki en modo single-node almacena datos en `/tmp/loki` por defecto. Si el contenedor se reinicia frecuentemente, agregue un volumen persistente:
```yaml
loki:
  volumes:
    - loki_data:/tmp/loki
```
Y declare `loki_data:` en la sección `volumes:` del compose.

## Referencias

- Loki Documentation: https://grafana.com/docs/loki/latest/
- Promtail Documentation: https://grafana.com/docs/loki/latest/send-data/promtail/
- LogQL (Loki Query Language): https://grafana.com/docs/loki/latest/query/
- Grafana – https://grafana.com/docs/grafana/latest/

---

*Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
