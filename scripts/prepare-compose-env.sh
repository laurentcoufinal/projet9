#!/usr/bin/env bash
# Prépare le .env à la racine du dépôt pour Docker Compose (local ou CI).
# - Local : utilise .env existant si OPENSEARCH_INITIAL_ADMIN_PASSWORD est défini
# - CI    : génère .env depuis OPENSEARCH_PASSWORD / OPENSEARCH_INITIAL_ADMIN_PASSWORD (secrets GitHub)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

load_env_file() {
  if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
    return 0
  fi
  return 1
}

if load_env_file && [[ -n "${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}" ]]; then
  echo "==> .env existant — OPENSEARCH_INITIAL_ADMIN_PASSWORD chargé"
  exit 0
fi

RESOLVED_PASS="${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-${OPENSEARCH_PASSWORD:-}}"

if [[ -z "${RESOLVED_PASS}" ]]; then
  echo "OPENSEARCH_INITIAL_ADMIN_PASSWORD absent." >&2
  echo "  Local : copier .env.example vers .env à la racine du dépôt" >&2
  echo "  CI    : configurer le secret GitHub OPENSEARCH_PASSWORD (ou exporter OPENSEARCH_INITIAL_ADMIN_PASSWORD)" >&2
  exit 1
fi

cat > "${ENV_FILE}" <<EOF
# Généré par scripts/prepare-compose-env.sh — ne pas committer
OPENSEARCH_INITIAL_ADMIN_PASSWORD=${RESOLVED_PASS}
OPENSEARCH_PASSWORD=${RESOLVED_PASS}
OPENSEARCH_HOST=localhost
OPENSEARCH_PORT=9200
OPENSEARCH_USERNAME=admin
OPENSEARCH_ENABLED=true
OPENSEARCH_SECURITY_ACCESS_LOG=true
EOF

echo "==> .env généré à la racine (mot de passe depuis variable d'environnement / secret GitHub)"
