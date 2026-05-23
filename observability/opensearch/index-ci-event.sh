#!/usr/bin/env bash
# Indexe un événement sécurité CI (Sonar, Dependabot, build) dans microcrm-security-events.
set -euo pipefail

OS_HOST="${OPENSEARCH_URL:-${OPENSEARCH_HOST:-https://localhost:9200}}"
OS_USER="${OPENSEARCH_USERNAME:-admin}"
OS_PASS="${OPENSEARCH_PASSWORD:-${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}}"
INDEX="${OPENSEARCH_SECURITY_INDEX:-microcrm-security-events}"

CI_EVENT="${1:-ci.unknown}"
WORKFLOW="${GITHUB_WORKFLOW:-local}"
JOB="${GITHUB_JOB:-manual}"
CONCLUSION="${2:-${CI_CONCLUSION:-unknown}}"
RUN_ID="${GITHUB_RUN_ID:-0}"

if [[ -z "${OS_PASS}" ]]; then
  echo "OPENSEARCH_PASSWORD non défini — événement CI non indexé"
  exit 0
fi

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DOC=$(cat <<EOF
{
  "timestamp": "${TS}",
  "eventCategory": "security",
  "eventType": "ci",
  "ci_event": "${CI_EVENT}",
  "workflow": "${WORKFLOW}",
  "job": "${JOB}",
  "conclusion": "${CONCLUSION}",
  "runId": "${RUN_ID}",
  "source": "github-actions",
  "ingest_source": "ci_script"
}
EOF
)

HTTP_CODE=$(curl -ks -o /tmp/ci-event-resp.txt -w "%{http_code}" \
  -u "${OS_USER}:${OS_PASS}" \
  -X POST "${OS_HOST}/${INDEX}/_doc" \
  -H 'Content-Type: application/json' \
  -d "${DOC}" || echo "000")

if [[ "${HTTP_CODE}" =~ ^(200|201)$ ]]; then
  echo "Événement CI indexé: ${CI_EVENT} (${CONCLUSION})"
else
  echo "OpenSearch indisponible (HTTP ${HTTP_CODE}) — événement CI ignoré"
  cat /tmp/ci-event-resp.txt 2>/dev/null || true
fi
