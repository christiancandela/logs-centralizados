#!/usr/bin/env bash
# setup.sh — Descarga el repositorio oficial de SigNoz a versión fija.
# Ejecutar una sola vez antes de levantar el stack.

set -euo pipefail

SIGNOZ_VERSION="v0.122.0"
TARGET_DIR="signoz"

if [ -d "$TARGET_DIR" ]; then
  echo "✅ El directorio '$TARGET_DIR' ya existe. No se hace nada."
  exit 0
fi

echo "⬇️  Clonando SigNoz $SIGNOZ_VERSION..."
git clone --depth 1 --branch "$SIGNOZ_VERSION" \
  https://github.com/SigNoz/signoz.git "$TARGET_DIR"

echo ""
echo "✅ Listo. Ahora puede levantar el stack con:"
echo ""
echo "  docker compose \\"
echo "    -f signoz/deploy/docker/docker-compose.yaml \\"
echo "    -f docker-compose.yml \\"
echo "    up -d --build"
