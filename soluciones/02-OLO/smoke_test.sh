#!/usr/bin/env bash
# smoke_test.sh — Prueba de humo automatizada para 02-OLO
set -euo pipefail

# Colores para la salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}🚀 Iniciando Prueba de Humo: Stack OLO (OpenSearch)${NC}"
echo -e "${BLUE}==================================================${NC}"

# Paso 1: Levantar el stack
echo -e "${YELLOW}⏳ Levantando contenedores y compilando logs.producer...${NC}"
docker compose down -v 2>/dev/null || true
docker compose up -d --build

# Asegurar limpieza al salir si falla
cleanup() {
  echo -e "${YELLOW}🧹 Limpiando el entorno y liberando recursos...${NC}"
  docker compose down -v
}
trap cleanup ERR

# Paso 2: Esperar a que logs.producer esté listo
PRODUCER_PORT=8080
echo -e "${YELLOW}⏳ Esperando a que logs.producer esté activo en el puerto $PRODUCER_PORT...${NC}"
READY=false
for i in {1..30}; do
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

# Paso 3: Enviar mensaje de prueba estructurado
TEST_MSG="SMOKETEST_OLO_$(date +%s)_$RANDOM"
echo -e "${YELLOW}✉️  Enviando log de prueba: '$TEST_MSG'...${NC}"
curl -s -X POST -H "Content-Type: application/json" -d "{\"level\":\"INFO\",\"message\":\"$TEST_MSG\"}" http://localhost:$PRODUCER_PORT/logs > /dev/null

# Paso 4: Esperar a que se indexe en OpenSearch
echo -e "${YELLOW}⏳ Buscando el log en OpenSearch (puerto 9200)...${NC}"
INDEXED=false
for i in {1..15}; do
  RESULT=$(curl -s "http://localhost:9200/_search?q=$TEST_MSG" || true)
  if echo "$RESULT" | grep -q "$TEST_MSG"; then
    INDEXED=true
    echo -e "${GREEN}🎉 ¡ÉXITO! Log encontrado indexado en OpenSearch!${NC}"
    break
  fi
  echo "   [Intento $i/15] Aún no indexado, esperando 3 segundos..."
  sleep 3
done

if [ "$INDEXED" = "false" ]; then
  echo -e "${RED}❌ ERROR: El log no fue indexado en OpenSearch a tiempo.${NC}"
  exit 1
fi

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}✅ PRUEBA DE HUMO FINALIZADA CON ÉXITO${NC}"
echo -e "${GREEN}==================================================${NC}"

# Limpieza final
cleanup
echo -e "${GREEN}👍 Todo limpio. ¡Prueba superada!${NC}"
