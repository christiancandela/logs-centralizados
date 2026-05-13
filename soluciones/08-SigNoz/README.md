# 08-SigNoz

Plataforma unificada de observabilidad con **SigNoz** y **ClickHouse**.

> ⚠️ **Si el IDE muestra errores en esta carpeta**, es porque el directorio `signoz/` aún no existe. Ejecute `./setup.sh` primero (ver abajo) y los errores desaparecerán.

## Antes de empezar

El repositorio oficial de SigNoz **no se incluye** en este repositorio (167 MB, 7000+ archivos). Descárguelo con el script de setup:

```bash
./setup.sh
```

Esto clona `https://github.com/SigNoz/signoz.git` a la versión `v0.122.0` en el directorio `signoz/`.

## Levantar el stack

```bash
docker compose \
  -f signoz/deploy/docker/docker-compose.yaml \
  -f docker-compose.yml \
  up -d --build
```

## Detener el stack

```bash
docker compose \
  -f signoz/deploy/docker/docker-compose.yaml \
  -f docker-compose.yml \
  down
```

Consulte `guias/signoz-guide.md` para la guía completa de uso y validación.
