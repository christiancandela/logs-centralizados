#!/usr/bin/env bash
# smoke_test.sh — Prueba de humo automatizada para 08-SigNoz
set -euo pipefail

# Colores para la salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}🚀 Iniciando Prueba de Humo: Stack SigNoz + ClickHouse${NC}"
echo -e "${BLUE}==================================================${NC}"

# Paso 0: Clonar SigNoz si no existe
if [ ! -d "signoz" ]; then
  echo -e "${YELLOW}⬇️  El directorio 'signoz' no existe. Ejecutando setup.sh primero...${NC}"
  ./setup.sh
fi

# Paso 1: Levantar el stack
echo -e "${YELLOW}⏳ Levantando contenedores (SigNoz + logs.producer) y compilando...${NC}"
docker compose -f signoz/deploy/docker/docker-compose.yaml -f docker-compose.yml down -v 2>/dev/null || true
docker compose -f signoz/deploy/docker/docker-compose.yaml -f docker-compose.yml up -d --build

# Asegurar limpieza al salir si falla
cleanup() {
  echo -e "${YELLOW}🧹 Limpiando el entorno y liberando recursos...${NC}"
  docker compose -f signoz/deploy/docker/docker-compose.yaml -f docker-compose.yml down -v
}
trap cleanup ERR

# Paso 2: Esperar a que logs.producer esté listo en puerto 8090
PRODUCER_PORT=8090
echo -e "${YELLOW}⏳ Esperando a que logs.producer esté activo en el puerto $PRODUCER_PORT...${NC}"
READY=false
for i in {1..40}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d '{"level":"INFO","message":"PING"}' http://localhost:$PRODUCER_PORT/logs || true)
  if [ "$CODE" = "200" ]; then
    READY=true
    echo -e "${GREEN}✅ logs.producer está listo y respondiendo!${NC}"
    break
  fi
  sleep 3
done

if [ "$READY" = "false" ]; then
  echo -e "${RED}❌ ERROR: logs.producer no inició a tiempo.${NC}"
  exit 1
fi

# Paso 2.5: Esperar a que el canal de ingesta se estabilice
echo -e "${YELLOW}⏳ Esperando 15 segundos adicionales para la estabilización de los canales de ingesta...${NC}"
sleep 15

# Paso 3: Definir el marcador único de prueba.
# A diferencia de los demás stacks, el envío se realiza de forma repetida dentro del
# bucle de verificación (Paso 4): el colector OTLP de SigNoz puede tardar ~45-60 s en
# estar listo para ingerir, por lo que un único envío temprano se perdería. Reenviar
# en cada iteración garantiza que el marcador llegue una vez el pipeline esté operativo.
TEST_MSG="SMOKETEST_SIGNOZ_$(date +%s)_$RANDOM"
echo -e "${YELLOW}✉️  Marcador de prueba: '$TEST_MSG' (se reenviará hasta confirmar la ingesta)...${NC}"

# Paso 4: Reenviar el marcador y esperar a que se indexe en ClickHouse
echo -e "${YELLOW}⏳ Buscando el log en la base de datos columnar ClickHouse de SigNoz...${NC}"
INDEXED=false
for i in {1..30}; do
  curl -s -X POST -H "Content-Type: application/json" -d "{\"level\":\"WARN\",\"message\":\"$TEST_MSG\"}" http://localhost:$PRODUCER_PORT/logs > /dev/null || true
  RESULT=$(docker compose -f signoz/deploy/docker/docker-compose.yaml -f docker-compose.yml exec -T clickhouse clickhouse-client --query "SELECT body FROM signoz_logs.distributed_logs_v2 WHERE body LIKE '%$TEST_MSG%'" || true)
  if echo "$RESULT" | grep -q "$TEST_MSG"; then
    INDEXED=true
    echo -e "${GREEN}🎉 ¡ÉXITO! Log encontrado indexado en ClickHouse de SigNoz!${NC}"
    break
  fi
  echo "   [Intento $i/30] Aún no indexado, reenviando y esperando 4 segundos..."
  sleep 4
done

if [ "$INDEXED" = "false" ]; then
  echo -e "${RED}❌ ERROR: El log no fue indexado en ClickHouse a tiempo.${NC}"
  exit 1
fi

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}✅ PRUEBA DE HUMO FINALIZADA CON ÉXITO${NC}"
echo -e "${GREEN}==================================================${NC}"

# Limpieza final
cleanup
echo -e "${GREEN}👍 Todo limpio. ¡Prueba superada!${NC}"
