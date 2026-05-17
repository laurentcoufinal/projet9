#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Build des images Docker Compose"
docker compose build

echo "==> Démarrage des services (back + front)"
docker compose up -d

cleanup() {
  echo "==> Arrêt des services"
  docker compose down
}
trap cleanup EXIT

echo "==> Attente du healthcheck backend"
for i in $(seq 1 30); do
  if curl -sf http://localhost:8080/persons >/dev/null 2>&1; then
    echo "Backend OK"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "Échec: le backend ne répond pas sur http://localhost:8080/persons"
    docker compose logs back
    exit 1
  fi
  sleep 2
done

echo "==> Vérification API"
curl -sf http://localhost:8080/persons | head -c 200
echo ""

echo "==> Vérification frontend (HTTP/HTTPS)"
curl -sfL -o /dev/null -w "Front HTTP status: %{http_code}\n" http://localhost:80/ || true

echo "==> Vérification frontend (HTTPS)"
curl -sfk -o /dev/null -w "Front HTTPS status: %{http_code}\n" https://localhost:443/

echo "==> Tous les contrôles Docker Compose ont réussi"
