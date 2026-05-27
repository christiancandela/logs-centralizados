#!/usr/bin/env bash
# smoke_test.sh — Prueba de humo automatizada para 05-GELF-Graylog
set -euo pipefail

# Colores para la salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}🚀 Iniciando Prueba de Humo: Stack GELF & Graylog${NC}"
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

# Paso 2.6: Crear el input GELF UDP en la API de Graylog
echo -e "${YELLOW}🔌 Creando el input GELF UDP en la API de Graylog...${NC}"
curl -s -H "Content-Type: application/json" \
     -H "X-Requested-By: curl" \
     -H "Authorization: Basic YWRtaW46YWRtaW4=" \
     -d '{"title":"GELF UDP","configuration":{"recv_buffer_size":262144,"bind_address":"0.0.0.0","port":12201,"decompress_size_limit":8388608},"type":"org.graylog2.inputs.gelf.udp.GELFUDPInput","global":true}' \
     http://localhost:9000/api/system/inputs > /dev/null || true

# Esperar a que el puerto UDP de Graylog esté bindeado y escuchando
echo -e "${YELLOW}⏳ Esperando 5 segundos para que el puerto UDP 12201 esté activo...${NC}"
sleep 5

# Paso 3: Enviar mensaje de prueba estructurado
TEST_MSG="SMOKETEST_GRAYLOG_$(date +%s)_$RANDOM"
echo -e "${YELLOW}✉️  Enviando log de prueba: '$TEST_MSG'...${NC}"
curl -s -X POST -H "Content-Type: application/json" -d "{\"level\":\"WARN\",\"message\":\"$TEST_MSG\"}" http://localhost:$PRODUCER_PORT/logs > /dev/null

# Paso 4: Esperar a que se indexe en OpenSearch (interno a través de docker compose exec)
echo -e "${YELLOW}⏳ Buscando el log en OpenSearch (interno en la red Docker)...${NC}"
INDEXED=false
for i in {1..20}; do
  RESULT=$(docker compose exec -T opensearch curl -s "http://localhost:9200/_search?q=$TEST_MSG" || true)
  if echo "$RESULT" | grep -q "$TEST_MSG"; then
    INDEXED=true
    echo -e "${GREEN}🎉 ¡ÉXITO! Log encontrado indexado en OpenSearch via Graylog GELF!${NC}"
    break
  fi
  echo "   [Intento $i/20] Aún no indexado, esperando 3 segundos..."
  sleep 3
done

if [ "$INDEXED" = "false" ]; then
  echo -e "${RED}❌ ERROR: El log no fue indexado en OpenSearch via Graylog a tiempo.${NC}"
  exit 1
fi

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}✅ PRUEBA DE HUMO FINALIZADA CON ÉXITO${NC}"
echo -e "${GREEN}==================================================${NC}"

# Limpieza final
cleanup
echo -e "${GREEN}👍 Todo limpio. ¡Prueba superada!${NC}"
