#!/usr/bin/env bash
# Prépare le .env à la racine du dépôt pour Docker Compose (local ou CI).
# - Local : utilise .env existant si OPENSEARCH_INITIAL_ADMIN_PASSWORD est défini
# - CI    : génère .env depuis OPENSEARCH_PASSWORD / OPENSEARCH_INITIAL_ADMIN_PASSWORD (secrets GitHub)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
DEBUG_LOG="${REPO_ROOT}/.cursor/debug-7ecea8.log"

#region agent log
_debug_log() {
  local hypothesis_id="$1" message="$2" data="$3"
  printf '{"sessionId":"7ecea8","runId":"%s","hypothesisId":"%s","location":"prepare-compose-env.sh","message":"%s","data":%s,"timestamp":%s}\n' \
    "${DEBUG_RUN_ID:-pre-fix}" "$hypothesis_id" "$message" "$data" "$(date +%s%3N)" >> "${DEBUG_LOG}" 2>/dev/null || true
}
#endregion

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

#region agent log
_debug_log "A" "start" "$(python3 -c "import json,os; print(json.dumps({'env_file_exists': os.path.isfile('${ENV_FILE}'), 'has_initial_in_env': bool(os.environ.get('OPENSEARCH_INITIAL_ADMIN_PASSWORD')), 'has_password_in_env': bool(os.environ.get('OPENSEARCH_PASSWORD'))}))")"
#endregion

if load_env_file && [[ -n "${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}" ]]; then
  #region agent log
  _debug_log "B" "use_existing_env_file" "$(python3 -c "import json; print(json.dumps({'source': 'file', 'password_set': True}))")"
  #endregion
  echo "==> .env existant — OPENSEARCH_INITIAL_ADMIN_PASSWORD chargé"
  exit 0
fi

RESOLVED_PASS="${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-${OPENSEARCH_PASSWORD:-}}"

if [[ -z "${RESOLVED_PASS}" ]]; then
  #region agent log
  _debug_log "C" "missing_password" "$(python3 -c "import json; print(json.dumps({'env_file_exists': __import__('os').path.isfile('${ENV_FILE}'), 'resolved': False}))")"
  #endregion
  echo "OPENSEARCH_INITIAL_ADMIN_PASSWORD absent." >&2
  echo "  Local : copier .env.example vers .env à la racine du dépôt" >&2
  echo "  CI    : configurer le secret GitHub OPENSEARCH_PASSWORD (ou exporter OPENSEARCH_INITIAL_ADMIN_PASSWORD)" >&2
  exit 1
fi

#region agent log
_debug_log "D" "resolved_from_secret_or_env" "$(python3 -c "import json; print(json.dumps({'source': 'env_var', 'env_file_existed': __import__('os').path.isfile('${ENV_FILE}'), 'will_write': True}))")"
#endregion

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
