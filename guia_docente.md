# Guía Docente

*Planificación pedagógica, rúbricas y orientaciones para la incorporación del recurso educativo en la asignatura **Arquitectura Orientada a Microservicios**.*

## 1. Propósito de esta guía

Este documento está dirigido al **docente** que utilizará el recurso en su curso. Su objetivo es facilitar la integración del material en una planificación realista, sugerir rutas de aprendizaje según el tiempo disponible, proponer instrumentos de evaluación y anticipar las dificultades más frecuentes que enfrentan los estudiantes.

El recurso completo está pensado para una unidad temática de **dos semanas** dentro de un curso semestral de 16 semanas. No se espera (ni es deseable) cubrir las nueve guías prácticas en ese tiempo; el diseño asume que el docente seleccionará dos o tres guías para trabajo en aula y dejará el resto como material de profundización para estudiantes interesados o como base para trabajos finales.

## 2. Ubicación pedagógica dentro del curso

La unidad sobre **observabilidad y centralización de logs** se inserta de forma natural después de que el estudiante ha trabajado los conceptos fundacionales de una arquitectura orientada a microservicios: descomposición de servicios, comunicación sincrónica/asincrónica, contenerización y orquestación básica. Específicamente, se recomienda ubicarla:

- **Después** de: introducción a microservicios, contenerización con Docker, comunicación entre servicios.
- **Antes** de: temas avanzados de resiliencia (circuit breakers, retries), seguridad distribuida y despliegue continuo, ya que estos requieren capacidad de observación operacional para razonar sobre ellos.

Una ubicación común y efectiva es entre **las semanas 9 y 11** del curso, una vez los estudiantes tienen aplicaciones distribuidas funcionales sobre las cuales aplicar el material.

## 3. Prerrequisitos del estudiante

Antes de iniciar la unidad, el estudiante debería ser capaz de:

- Levantar contenedores y stacks multi-servicio con `docker compose`.
- Comprender el modelo cliente-servidor y los conceptos básicos de redes (puertos, protocolos TCP/UDP).
- Tener nociones básicas de formatos estructurados como JSON.
- Haber escrito al menos una aplicación Java/Quarkus simple, ya que todas las guías usan este *stack* como productor de logs.

## 4. Resultados de aprendizaje de la unidad

Al finalizar las dos semanas, el estudiante debe ser capaz de:

1. **Explicar** qué es la observabilidad y por qué es un requisito de diseño (no un complemento operativo) en arquitecturas distribuidas.
2. **Describir** la arquitectura conceptual de cuatro etapas (recolección, procesamiento, almacenamiento, visualización) y reconocerla en al menos dos implementaciones tecnológicamente distintas.
3. **Justificar** los desafíos transversales de estandarización semántica, ciclo de vida del dato y sanitización de información sensible.
4. **Desplegar y validar** al menos un stack completo de centralización de logs sobre un entorno reproducible con Docker Compose.
5. **Contrastar** decisiones arquitectónicas entre stacks (por ejemplo: indexación completa vs. solo etiquetas; protocolo específico vs. estándar unificado).

## 5. Rutas sugeridas

### 5.1 Ruta mínima (2 semanas, 4 sesiones)

Es la ruta recomendada para la unidad estándar. Cubre teoría completa y dos guías prácticas que ilustran enfoques contrastados.

| Sesión | Duración | Contenido | Material |
|--------|----------|-----------|----------|
| **1** | 2 h | Observabilidad, logs como pilar, dispersión y centralización. Beneficios de la centralización. | [Marco conceptual](readme.md): observabilidad → beneficios |
| **2** | 2 h | Arquitectura conceptual de cuatro etapas. Desafíos de diseño (estandarización, retención, sanitización). Presentación de los stacks disponibles. | [Marco conceptual](readme.md): desafíos y arquitectura · recorrido de las [guías prácticas](guias/) |
| **3** | 2 h | **Laboratorio 1** — Stack base: ELK *o* PLG. Despliegue, ingreso de logs y consultas básicas. | [Guía ELK](guias/elk-guide.md) *o* [Guía PLG](guias/promtail-guide.md) |
| **4** | 2 h | **Laboratorio 2 + Cierre** — Stack contrastante: OpenTelemetry *o* Vector. Discusión comparada y evaluación. | [Guía OpenTelemetry](guias/otel-guide.md) *o* [Guía Vector](guias/vector-guide.md) |

**Recomendación de pares contrastantes:**

- **ELK + OpenTelemetry:** contrapone el stack clásico de indexación completa con el estándar unificado moderno.
- **PLG + Vector:** ambos usan Loki como *backend*, pero el agente cambia radicalmente (Promtail vs. Vector); pedagógicamente valioso para mostrar que la elección del recolector es independiente del almacenamiento.
- **ELK + PLG:** contrapone los dos paradigmas de almacenamiento (texto completo vs. solo etiquetas), ideal si se quiere foco en decisiones de almacenamiento.

### 5.2 Ruta extendida (electiva o trabajo final)

Para estudiantes que desarrollarán un trabajo final, electiva especializada o semillero de investigación, se propone la ruta progresiva descrita en el documento base: ELK → OLO → Fluentd → PLG → GELF/Graylog → OpenTelemetry → Vector → SigNoz → Alloy. Esta ruta puede cubrirse en un semestre completo de electiva o como guion de un módulo de profundización.

### 5.3 Ruta corta (1 semana, 2 sesiones)

Si la unidad debe condensarse en una sola semana:

| Sesión | Contenido |
|--------|-----------|
| **1** | Toda la teoría conceptual del [documento base](readme.md), centrándose en los conceptos esenciales y delegando lecturas a casa. |
| **2** | Un único laboratorio con la guía de **OpenTelemetry**, por ser la más representativa del estado del arte y cubrir los tres pilares en una sola implementación. |

## 6. Estrategia de evaluación

Se propone una evaluación de **tres componentes** con peso ponderado, alineada con los resultados de aprendizaje siguiendo el principio de **alineación constructiva** (coherencia explícita entre resultados de aprendizaje, actividades y criterios de evaluación). Los porcentajes son sugerencias; el docente debe ajustarlos a la ponderación general del curso. La rúbrica y los entregables definidos en esta sección constituyen los **instrumentos de evaluación homogéneos** del recurso, aplicables de forma uniforme a cualquiera de las nueve guías prácticas.

### 6.1 Componente conceptual (30 %)

**Instrumento:** Cuestionario corto con preguntas seleccionadas de la [guía de estudio](guia_estudio.md).

**Recomendación:** seleccionar 5 preguntas mezclando el bloque teórico (preguntas conceptuales y glosario) y el bloque de articulación teoría–práctica. Las preguntas de articulación son las que mejor discriminan entre estudiantes que leyeron y estudiantes que comprendieron.

### 6.2 Componente práctico (40 %)

**Instrumento:** Informe de laboratorio sobre el despliegue de uno de los stacks trabajados en clase.

**Entregables exigibles:**

- Repositorio o carpeta con el `docker-compose.yml` y archivos de configuración funcionales.
- Capturas del estado de validación (contenedores arriba, logs visibles, consulta efectiva en el visualizador).
- Reflexión escrita (máx. 500 palabras) que responda explícitamente: *¿qué etapas de la arquitectura conceptual identifica en su despliegue y qué componente concreto cumple cada una?*

> [!TIP]
> **Ayuda de validación:** cada solución del repositorio incluye un script `smoke_test.sh` que despliega el stack, emite un log de prueba y verifica su registro de extremo a extremo. El estudiante puede ejecutarlo para comprobar objetivamente que su entorno funciona antes de capturar las evidencias.

**Rúbrica sugerida:**

| Criterio | Peso | Excelente (5.0) | Aceptable (3.0) | Insuficiente (1.0) |
|----------|------|-----------------|-----------------|---------------------|
| Despliegue funcional | 40 % | Stack completo en ejecución, logs fluyendo, consultas efectivas | Stack arriba pero con fallos parciales | No logra arrancar el stack |
| Identificación arquitectónica | 30 % | Mapea correctamente las cuatro etapas a componentes concretos | Identifica algunas etapas con imprecisiones menores | Confunde etapas o no las identifica |
| Reflexión escrita | 20 % | Articula decisiones de diseño y compromisos | Describe lo realizado sin análisis | Reproduce contenido de la guía sin elaboración |
| Calidad técnica | 10 % | Configuración limpia, versionada, reproducible | Configuración funcional pero desordenada | Configuración no reproducible |

### 6.3 Componente integrador (30 %)

**Instrumento:** Ensayo comparativo breve (máx. 1000 palabras) que contraste **dos stacks** vistos en clase a partir de **al menos dos criterios** del marco teórico (por ejemplo: modelo de almacenamiento, acoplamiento del recolector, soporte para los tres pilares, gestión de la sanitización).

Este componente evalúa el resultado de aprendizaje 5 (capacidad de contrastar decisiones arquitectónicas), que es el de mayor nivel cognitivo y el que distingue una formación conceptual de una meramente operativa.

## 7. Dificultades frecuentes y cómo anticiparlas

A continuación se enumeran las fricciones más comunes que experimentan los estudiantes al trabajar con el recurso, junto con orientaciones para anticiparlas en clase.

### 7.1 Memoria RAM insuficiente

Los stacks ELK, OLO, GELF/Graylog y SigNoz consumen entre 4 y 6 GB en estado estable. En equipos con 8 GB totales o menos, el sistema entra en *swapping* y los contenedores fallan con `OOMKilled` o tiempos de arranque muy largos.

**Recomendación docente:** Antes de iniciar el laboratorio, validar que cada equipo tenga al menos 8 GB de RAM libres. Para estudiantes con equipos limitados, redirigir hacia las guías de **PLG, Vector o Alloy**, que funcionan cómodamente con 4 GB. Como alternativa, los límites de memoria de cada contenedor están parametrizados mediante variables `*_MEM_LIMIT` en el archivo `.env` de cada solución, por lo que pueden reducirse para ajustar un stack a equipos con menos memoria (a costa de un arranque más lento).

### 7.2 `vm.max_map_count` en Linux/WSL

Elasticsearch y OpenSearch requieren `vm.max_map_count ≥ 262144` en el *kernel* del *host*. En Linux y WSL este valor no se ajusta automáticamente y el contenedor falla en el arranque sin mensaje claro.

**Recomendación docente:** Cubrir este punto en la sesión 2, antes del laboratorio. Las guías afectadas incluyen el comando correctivo en su sección de troubleshooting.

### 7.3 Conflictos de puertos

Varias guías exponen puertos comunes (3000 para Grafana, 5601 para Kibana, 9200 para Elasticsearch, 8080 para la aplicación de prueba). Si el estudiante ya tiene servicios escuchando en esos puertos, los contenedores fallan.

**Recomendación docente:** Recordar el comando `lsof -i :PUERTO` (macOS/Linux) o `netstat -ano | findstr :PUERTO` (Windows) para diagnosticar el conflicto.

### 7.4 Formato ECS y claves planas con punto

Quarkus emite logs en formato ECS con claves planas como `{"log.level":"INFO"}`. Las etapas de procesamiento basadas en `json` interpretan el punto como ruta anidada, lo que impide extraer el campo. Por eso varias guías usan expresiones regulares en lugar del *parser* JSON estándar.

**Recomendación docente:** Discutir este caso explícitamente como ilustración de la **estandarización semántica imperfecta**: aún con ECS, hay matices de interpretación que pueden romper un pipeline.

### 7.5 Confusión entre los formatos de configuración

Cada herramienta introduce su propio lenguaje de configuración: YAML (Promtail, ELK), TOML (Vector), `.alloy` (Alloy), `fluent.conf` (Fluentd), Logstash DSL. Los estudiantes suelen pegar configuraciones de una guía en otra y obtener errores.

**Recomendación docente:** Enfatizar desde la sesión 2 que cada herramienta tiene su propio lenguaje y que la habilidad transferible es leer la documentación del producto, no memorizar sintaxis.

## 8. Recomendaciones de articulación con otras unidades del curso

| Unidad del curso | Articulación posible |
|------------------|----------------------|
| Comunicación entre microservicios | Usar las trazas de OpenTelemetry para visualizar las llamadas REST/gRPC trabajadas en esa unidad |
| Resiliencia (retries, circuit breakers) | Usar los logs centralizados para observar el comportamiento del circuit breaker bajo fallo simulado |
| Seguridad | Usar el ejercicio de sanitización con VRL (guía Vector) para discutir manejo de credenciales en logs |
| Despliegue continuo | El recurso completo se despliega con `docker compose`; puede extenderse a Kubernetes en una unidad posterior |

## 9. Mantenimiento y evolución del recurso

El ecosistema de observabilidad evoluciona rápidamente; las versiones de las imágenes Docker quedan obsoletas en plazos de 12 a 18 meses. Se recomienda al docente que reutilice este material:

- Verificar las versiones de las imágenes en las guías al inicio de cada semestre.
- Reportar errores o sugerencias al equipo autor a través del repositorio del recurso.
- Considerar contribuciones de los propios estudiantes (actualización de versiones, nuevas guías) como actividad complementaria de aprendizaje.

## 10. Contacto

Para consultas sobre el uso pedagógico, propuestas de mejora o solicitudes de colaboración:

- Ph.D. Christian Andrés Candela Uribe — Profesor Asociado, Universidad del Quindío
- M.Sc. Paola Andrea Acero Franco — Profesor Asociado, Universidad del Quindío
- Ph.D. Luis Eduardo Sepúlveda Rodríguez — Profesor Asociado, Universidad del Quindío

---

> Este documento forma parte del *Recurso educativo para el despliegue de ecosistemas de centralización de logs mediante Docker* (Versión 1.0.0). Licencia CC BY-SA 4.0.
