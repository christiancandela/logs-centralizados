# Centralización de Logs con Grafana Alloy y Loki

> *Guía práctica complementaria a la guía Promtail. Implementa la misma arquitectura de centralización por archivo (*file tailing*) utilizando **Grafana Alloy**, el sucesor oficial de Promtail, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.*

> **Prerequisito recomendado:** Completar primero la guía Promtail. Esta guía asume familiaridad con Loki, LogQL y el modelo de indexación por etiquetas. El foco está en las diferencias de configuración entre Promtail y Alloy, no en los conceptos base.

---

## Objetivo de la guía

Implementar y validar una arquitectura de centralización de logs mediante **Docker Compose**, migrando el agente de recolección de **Promtail** a **Grafana Alloy**, y comprendiendo el nuevo modelo de configuración orientado a componentes (*dataflow*) que introduce Alloy.

---

## Resultados de aprendizaje esperados

Al finalizar esta guía, el estudiante será capaz de:

- Explicar por qué Grafana Labs puso Promtail en modo mantenimiento y qué ventajas aporta Alloy como sucesor.
- Distinguir el modelo de configuración declarativo-dataflow de Alloy frente al modelo implícito de Promtail.
- Configurar los componentes `local.file_match`, `loki.source.file`, `loki.process` y `loki.write` para construir un pipeline de *file tailing* hacia Loki.
- Utilizar la interfaz web integrada de Alloy para inspeccionar el estado de los componentes en tiempo real.
- Migrar conceptualmente una configuración Promtail existente a Alloy.

---

## Propósito y alcance del recurso

**Grafana Alloy** (v1.x) es el sucesor unificado de Promtail y del Grafana Agent. A diferencia de Promtail, que es un agente especializado en *file tailing* hacia Loki, Alloy es una plataforma de telemetría genérica que puede recolectar logs, métricas y trazas desde múltiples fuentes y enviarlos a múltiples destinos.

El modelo de configuración de Alloy es explícitamente **orientado al flujo de datos**: los componentes se declaran por separado y se conectan entre sí mediante referencias explícitas (`forward_to`). Esto lo hace más verboso para casos simples, pero significativamente más claro y flexible para pipelines complejos.

Esta guía se limita al caso de uso equivalente a Promtail: *file tailing* de logs estructurados en JSON hacia Loki.

---

## 1. Promtail vs Grafana Alloy

| Concepto | Promtail (YAML) | Grafana Alloy (Alloy syntax) |
|---|---|---|
| Formato de config | YAML (`promtail-config.yaml`) | HCL-like (`.alloy`) |
| Descubrimiento de archivos | `scrape_configs[].file_sd_configs` | Componente `local.file_match` |
| Lectura del archivo | Implícito en el job de scrape | Componente explícito `loki.source.file` |
| Pipeline de procesamiento | Array `pipeline_stages` dentro del job | Componente `loki.process` con bloques `stage.*` |
| Extracción de campos JSON | `stage.json` o `stage.regex` | `stage.json` o `stage.regex` (mismo modelo) |
| Promoción a etiquetas | `stage.labels` | `stage.labels` |
| Destino Loki | `clients: [url: ...]` (top-level) | Componente `loki.write` con bloque `endpoint` |
| Flujo de datos | **Implícito** (stages en cadena por job) | **Explícito** (wiring con `forward_to`) |
| Archivo de posiciones | `positions.filename` en config | Gestionado automáticamente en `--storage.path` |
| Recarga en caliente | SIGHUP o `/-/reload` | `/-/reload` HTTP o SIGHUP |
| Interfaz de inspección | Ninguna | UI web en `:12345` con grafo de componentes |

---

## 2. Requisitos previos

- Docker instalado
  https://docs.docker.com/engine/install/
- Docker Compose
  https://docs.docker.com/compose/install/
- Al menos **4 GB de RAM** libres (este stack no incluye Elasticsearch ni OpenSearch; Alloy, Loki y Grafana tienen un huella de memoria significativamente menor que los stacks ELK/OLO — este requisito reducido es en sí mismo un punto de comparación pedagógico con las guías anteriores)

### Dimensionamiento de recursos

**Consumo estimado del stack:** ~2.5 GB de RAM en estado estable. Se trata de un stack ligero, apto para equipos con tan solo 4 GB de RAM disponibles.

Cada servicio declara un `mem_limit` que acota su consumo de memoria. La siguiente tabla resume el rol de cada contenedor en el pipeline y su límite por defecto:

| Servicio | Función en el pipeline | `mem_limit` por defecto |
|----------|------------------------|-------------------------|
| `logs.producer` | Aplicación Quarkus que genera los logs (fuente de datos) | `512m` |
| `alloy` | Recolector y procesador del pipeline (lee, transforma y envía) | `512m` |
| `loki` | Almacenamiento e indexación por etiquetas de los logs | `512m` |
| `grafana` | Visualización y consulta de los logs | `512m` |

Los límites son parametrizables mediante variables de entorno definidas en un archivo `.env` junto al `docker-compose.yml`, lo que permite ajustarlos sin editar el compose:

```bash
PRODUCER_MEM_LIMIT=512m
ALLOY_MEM_LIMIT=512m
LOKI_MEM_LIMIT=512m
GRAFANA_MEM_LIMIT=512m
```

---

## 3. Estructura del proyecto

```bash
09-Alloy/
├── docker-compose.yml
├── alloy/
│   └── config.alloy          <-- Configuración del pipeline Alloy
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── loki.yaml
├── logs/                      <-- Volumen compartido: producer escribe, Alloy lee
└── logs.producer/
    ├── src/
    └── pom.xml
```

---

## 4. Arquitectura de la solución

```text
[Aplicación Quarkus / logs.producer]
         |
   (Escribe JSON en archivo)
         v
  [Volumen compartido ./logs]
         |
   (local.file_match → loki.source.file)
         v
  [Grafana Alloy :12345]
   loki.process (regex + labels)
         |
   (loki.write / HTTP push)
         v
     [Loki 3.0] ──→ [Grafana 13.0]
```

La arquitectura es funcionalmente idéntica a la de la guía Promtail. La diferencia es interna: el pipeline de Alloy es un **grafo de componentes** con conexiones explícitas en lugar de una lista de etapas implícitas.

---

## 5. Implementación

### 5.1 `docker-compose.yml`

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
    depends_on:
      alloy:
        condition: service_healthy

  alloy:
    image: grafana/alloy:v1.16.1
    container_name: alloy
    mem_limit: ${ALLOY_MEM_LIMIT:-512m}
    command:
      - run
      - --server.http.listen-addr=0.0.0.0:12345
      - --storage.path=/var/lib/alloy/data
      - /etc/alloy/config.alloy
    volumes:
      - ./alloy/config.alloy:/etc/alloy/config.alloy:ro
      - ./logs:/var/log/app:ro
      - alloy_data:/var/lib/alloy/data
    ports:
      - "12345:12345"
    healthcheck:
      # La imagen de Alloy no incluye wget ni curl.
      # Verificamos que el puerto 12345 esté en estado LISTEN vía /proc/net/tcp6.
      test: ["CMD-SHELL", "grep -q '3039' /proc/net/tcp6 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 6
      start_period: 20s
    depends_on:
      loki:
        condition: service_healthy

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

volumes:
  alloy_data:
```

> [!NOTE]
> **El comando de Alloy:** A diferencia de Promtail, que usa `--config.file=`, Alloy recibe la ruta del archivo de configuración como **argumento posicional** al final del comando `alloy run`. El flag `--server.http.listen-addr` es obligatorio para exponer la UI y los endpoints de salud.

> [!NOTE]
> **El healthcheck:** La imagen de Alloy no incluye `wget` ni `curl`. El puerto 12345 en hexadecimal es `0x3039`; verificamos su presencia en `/proc/net/tcp6` como alternativa portable.

---

### 5.2 Pipeline de Alloy (`alloy/config.alloy`)

```alloy
// ─── 1. Descubrir el archivo de log ─────────────────────────────────────────
local.file_match "quarkus_logs" {
  path_targets = [{"__path__" = "/var/log/app/*.log"}]
  sync_period  = "5s"
}

// ─── 2. Leer el archivo (file tailing) ──────────────────────────────────────
loki.source.file "quarkus_tail" {
  targets    = local.file_match.quarkus_logs.targets
  forward_to = [loki.process.enrich.receiver]
}

// ─── 3. Extraer el nivel de log y enriquecer con etiquetas ──────────────────
// El formato ECS de Quarkus produce claves planas con punto: {"log.level":"INFO",...}
// stage.regex extrae el nivel con la misma expresión validada en la guía Promtail.
loki.process "enrich" {
  stage.regex {
    expression = "\"log\\.level\":\"(?P<level>[^\"]+)\""
  }

  stage.labels {
    values = {
      "level" = "",
    }
  }

  stage.static_labels {
    values = {
      "job"         = "alloy_app_logs",
      "environment" = "dev",
    }
  }

  forward_to = [loki.write.loki_backend.receiver]
}

// ─── 4. Enviar a Loki ────────────────────────────────────────────────────────
loki.write "loki_backend" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

> [!NOTE]
> **`log.level` en ECS:** El formato ECS de Quarkus produce la clave con el punto como parte del nombre (`"log.level"`), no como estructura anidada. `stage.json` de Alloy interpreta el punto como separador de ruta (igual que Promtail), por lo que se usa `stage.regex` con la expresión `"log\\.level"` — la misma estrategia validada en la guía Promtail.

> [!NOTE]
> **`forward_to`:** El wiring explícito es la diferencia conceptual central de Alloy. `loki.source.file.quarkus_tail` envía a `loki.process.enrich.receiver`; este a su vez envía a `loki.write.loki_backend.receiver`. Este grafo es visible en la UI de Alloy en `http://localhost:12345`.

---

### 5.3 Configuración de la aplicación (`application.properties`)

Idéntica a la guía Promtail: la aplicación escribe en archivo JSON, sin conocimiento del agente que la lee.

```properties
quarkus.log.console.json=false

# Escribir logs estructurados en formato JSON al archivo compartido con Alloy
quarkus.log.file.enable=true
quarkus.log.file.json=true
quarkus.log.file.path=/deployments/logs/application.log
quarkus.log.file.json.exception-output-type=formatted
quarkus.log.file.json.log-format=ECS
```

---

## 6. Despliegue y validación

Antes de levantar el stack, cree el directorio compartido para los logs:

```bash
mkdir -p logs
```

Luego ejecute:

```bash
docker compose up -d --build
```

Verifique que los servicios estén activos:

```bash
docker compose ps
```

---

## 7. Interfaz de Alloy

Acceda a `http://localhost:12345` para ver la **UI de Alloy**. Desde allí puede:

- Ver el **grafo de componentes** con el estado de cada uno (verde = saludable).
- Inspeccionar los datos que fluyen por cada conexión en tiempo real (*Live Debugging*).
- Consultar las métricas internas de Alloy (`/metrics`).
- Recargar la configuración sin reiniciar (`/-/reload`).

Esta interfaz no existe en Promtail y es una de las ventajas operativas más importantes de Alloy.

---

## 8. Emisión de logs desde la aplicación

> **Reutilización de la aplicación:** Si ya completó la guía Promtail, puede reutilizar la misma aplicación `logs.producer` — la configuración de escritura a archivo JSON (`application.properties`) es idéntica. Si aún no la tiene, créela con el siguiente comando:

```shell
mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \
    -DprojectGroupId=co.uniquindio.ingesis.logs \
    -DprojectArtifactId=logs.producer \
    -Dextensions='rest,logging-json' \
    -DnoCode
```

Configure la escritura a archivo JSON en `application.properties`:

```properties
quarkus.log.console.json=false

# Escribir logs estructurados en formato JSON al archivo compartido con Alloy
quarkus.log.file.enable=true
quarkus.log.file.json=true
quarkus.log.file.path=/deployments/logs/application.log
quarkus.log.file.json.exception-output-type=formatted
quarkus.log.file.json.log-format=ECS
```

La aplicación expone los mismos endpoints que en las guías anteriores:

| Método | Path | Descripción |
|--------|------|-------------|
| `POST` | `/logs` | Emite un log al nivel indicado |
| `GET`  | `/api/error` | Genera una `NullPointerException` intencional |

```bash
# Emitir logs de prueba
curl -X POST http://localhost:8080/logs \
  -H "Content-Type: application/json" \
  -d '{"level":"INFO","message":"Hola desde Alloy"}'

# Generar un error
curl http://localhost:8080/api/error
```

---

## 9. Visualización en Grafana

Acceda a Grafana en `http://localhost:3000`. La fuente de datos Loki está preconfigurada.

**Consultas LogQL de ejemplo:**

Todos los logs del pipeline Alloy:
```logql
{job="alloy_app_logs"}
```

Filtrar por nivel:
```logql
{job="alloy_app_logs", level="ERROR"}
```

Analizar el JSON y mostrar solo el mensaje:
```logql
{job="alloy_app_logs"} | json | line_format "{{.message}}"
```

---

## 10. Actividades de profundización

- **Comparar el grafo de componentes con la guía Promtail:** Dibuje o esquematice el pipeline equivalente en Promtail y compare la verbosidad y claridad de ambas configuraciones. ¿Cuándo es preferible cada modelo?
- **Usar la migración automática:** Ejecute `alloy convert --source-format=promtail --config.file=promtail-config.yaml` con la configuración de la guía anterior. Compare la salida con `config.alloy` de esta guía.
- **Añadir una segunda fuente:** Modifique `config.alloy` para leer también `/var/log/app/*.json` (un segundo glob) y etiquetarlo con `source="json"`. ¿Cómo se haría en Promtail?
- **Inspeccionar el *live debugging*:** Desde la UI de Alloy (`http://localhost:12345`), active la depuración en vivo del componente `loki.process.enrich` y observe los eventos que atraviesan el pipeline mientras genera carga.
- **Evaluar el estado de mantenimiento:** Investigue qué funcionalidades tiene Grafana Alloy que Promtail no tendrá jamás (soporte OTLP, Pyroscope, integración con Kubernetes, etc.) y analice las implicaciones para la decisión de migración en un proyecto real.

### Cuestionario de análisis crítico

1. ¿Por qué no es posible usar `stage.json` con la expresión `"log.level"` para extraer el nivel de los logs ECS de Quarkus en Alloy, y cuál es la diferencia entre un campo con punto en el nombre y un campo anidado?
2. El healthcheck de Alloy usa `/proc/net/tcp6` en lugar de `wget` o `curl`. Explique qué limitación de la imagen impone esta solución y proponga una alternativa basada en un Dockerfile personalizado.
3. Compare el modelo de configuración de Alloy (*dataflow* explícito con `forward_to`) con el de Promtail (*stages* implícitas en cadena). ¿En qué escenario de producción el modelo de Alloy ofrece una ventaja clara?

---

## 11. Troubleshooting

**Alloy queda en estado `unhealthy` al arrancar.**

**Causa:** La imagen de Alloy no incluye `wget` ni `curl`. El healthcheck de esta guía usa `/proc/net/tcp6`, que requiere que el puerto 12345 esté en estado LISTEN. Si Alloy tarda en abrir el puerto, el `start_period` de 20 segundos debería ser suficiente.

**Solución:** Verifique los logs con `docker compose logs alloy`. Si hay errores de sintaxis en `config.alloy`, Alloy no arrancará y el puerto nunca se abrirá. Valide la sintaxis localmente con `docker run --rm -v $(pwd)/alloy:/etc/alloy grafana/alloy:v1.16.1 fmt /etc/alloy/config.alloy`.

---

**Los logs no aparecen en Loki / Grafana.**

**Causas posibles:**
1. El directorio `./logs` no existe o está vacío — `logs.producer` no ha podido escribir el archivo.
2. El componente `loki.source.file` no encuentra el glob `/var/log/app/*.log` porque el archivo no se ha creado aún.

**Solución:** Verifique que `./logs/application.log` exista tras el arranque de `logs.producer`:
```bash
ls -la logs/
docker compose logs logs.producer | tail -10
```
Luego inspeccione el estado de los componentes en la UI de Alloy (`http://localhost:12345`).

---

**Error de sintaxis en `config.alloy`.**

**Solución:** Alloy incluye un formateador y validador:
```bash
docker run --rm \
  -v $(pwd)/alloy:/etc/alloy \
  grafana/alloy:v1.16.1 \
  fmt /etc/alloy/config.alloy
```
Si hay errores de sintaxis, el comando los reporta con la línea exacta.

---

## Referencias

- Grafana Alloy Documentation: https://grafana.com/docs/alloy/latest/
- Migrate from Promtail to Alloy: https://grafana.com/docs/alloy/latest/set-up/migrate/from-promtail/
- loki.source.file: https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.file/
- loki.process: https://grafana.com/docs/alloy/latest/reference/components/loki/loki.process/
- Alloy configuration syntax: https://grafana.com/docs/alloy/latest/get-started/configuration-syntax/
- LogQL (Loki Query Language): https://grafana.com/docs/loki/latest/query/
- Grafana Documentation: https://grafana.com/docs/grafana/latest/

---

*Esta guía complementa la guía Promtail y el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.*
