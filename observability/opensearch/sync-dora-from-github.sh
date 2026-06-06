#!/usr/bin/env bash
# Synchronise l'historique GitHub Actions vers microcrm-dora-metrics (OpenSearch).
# Auth : GITHUB_TOKEN (PAT) ou gh CLI en local.
# Usage: ./observability/opensearch/sync-dora-from-github.sh [-d 90] [owner/repo]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

REPO="${GITHUB_REPOSITORY:-laurentcoufinal/projet9}"
DAYS="${DORA_SYNC_DAYS:-90}"
METRICS_DAYS=28
INDEX="${OPENSEARCH_DORA_INDEX:-microcrm-dora-metrics}"

normalize_os_host() {
  local host="${OPENSEARCH_HOST:-localhost}"
  local port="${OPENSEARCH_PORT:-9200}"
  if [[ -n "${OPENSEARCH_URL:-}" ]]; then
    printf '%s' "${OPENSEARCH_URL}"
  elif [[ "${host}" == http://* || "${host}" == https://* ]]; then
    printf '%s' "${host}"
  else
    printf 'https://%s:%s' "${host}" "${port}"
  fi
}

OS_HOST="$(normalize_os_host)"
OS_USER="${OPENSEARCH_USERNAME:-admin}"
OS_PASS="${OPENSEARCH_PASSWORD:-${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}}"

DORA_COMPUTE="${DORA_COMPUTE_PATH:-${REPO_ROOT}/scripts/lib/dora_compute.py}"
if [[ ! -f "${DORA_COMPUTE}" && -f /app/dora_compute.py ]]; then
  DORA_COMPUTE="/app/dora_compute.py"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--days) DAYS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [-d 90] [owner/repo]"
      exit 0
      ;;
    *)
      REPO="$1"
      shift
      ;;
  esac
done

if [[ -z "${OS_PASS}" ]]; then
  echo "OPENSEARCH_PASSWORD non défini — sync DORA ignorée"
  exit 0
fi

if [[ -z "${GITHUB_TOKEN:-}" ]] && ! command -v gh >/dev/null 2>&1; then
  echo "GITHUB_TOKEN ou gh CLI requis — sync DORA ignorée"
  exit 0
fi

if [[ ! -f "${DORA_COMPUTE}" ]]; then
  echo "Module introuvable: ${DORA_COMPUTE}" >&2
  exit 1
fi

echo "==> Fetch GitHub Actions: ${REPO} (fenêtre ${DAYS} jours)"
RUNS_JSON="$(python3 "${DORA_COMPUTE}" fetch --repo "${REPO}" --token "${GITHUB_TOKEN:-}")"

RUN_COUNT="$(echo "${RUNS_JSON}" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
echo "==> Runs récupérés: ${RUN_COUNT}"

BULK_BODY="$(echo "${RUNS_JSON}" | python3 "${DORA_COMPUTE}" bulk --repo "${REPO}" --index "${INDEX}" --days "${DAYS}")"
BULK_LINES="$(printf '%s\n' "${BULK_BODY}" | grep -c '^{' || true)"
DOC_COUNT=$((BULK_LINES / 2))
echo "==> Indexation bulk: ${DOC_COUNT} workflow_run"

if [[ "${DOC_COUNT}" -gt 0 ]]; then
  HTTP_CODE="$(printf '%s\n' "${BULK_BODY}" | curl -ks -o /tmp/dora-bulk-resp.txt -w "%{http_code}" \
    -u "${OS_USER}:${OS_PASS}" \
    -X POST "${OS_HOST}/_bulk?refresh=wait_for" \
    -H 'Content-Type: application/x-ndjson' \
    --data-binary @- || echo "000")"
  if [[ ! "${HTTP_CODE}" =~ ^2 ]]; then
    echo "Bulk OpenSearch échoué (HTTP ${HTTP_CODE})" >&2
    head -c 400 /tmp/dora-bulk-resp.txt 2>/dev/null || true
    echo
    exit 1
  fi
fi

METRICS_JSON="$(echo "${RUNS_JSON}" | python3 "${DORA_COMPUTE}" metrics --repo "${REPO}" --days "${METRICS_DAYS}")"
SNAPSHOT_JSON="$(echo "${METRICS_JSON}" | python3 "${DORA_COMPUTE}" snapshot)"
SNAPSHOT_ID="snapshot-$(date -u +%Y%m%dT%H%M%SZ)"

HTTP_CODE="$(printf '%s' "${SNAPSHOT_JSON}" | curl -ks -o /tmp/dora-snapshot-resp.txt -w "%{http_code}" \
  -u "${OS_USER}:${OS_PASS}" \
  -X PUT "${OS_HOST}/${INDEX}/_doc/${SNAPSHOT_ID}?refresh=wait_for" \
  -H 'Content-Type: application/json' \
  -d @- || echo "000")"

if [[ ! "${HTTP_CODE}" =~ ^2 ]]; then
  echo "Snapshot DORA échoué (HTTP ${HTTP_CODE})" >&2
  head -c 400 /tmp/dora-snapshot-resp.txt 2>/dev/null || true
  echo
  exit 1
fi

echo "${METRICS_JSON}" | python3 -c "
import json, sys
m = json.load(sys.stdin)
print('==> Snapshot DORA indexé')
print(f\"  Lead Time      : {m.get('lead_time_minutes', 'n/a')} min\")
print(f\"  Deploy Freq    : {m.get('deployment_frequency_per_week', 'n/a')} / semaine\")
print(f\"  MTTR           : {m.get('mttr_hours', 'n/a')} h\")
print(f\"  Change Fail %  : {m.get('change_failure_rate_pct', 'n/a')} %\")
"
