#!/usr/bin/env bash
# Provisionne index template, objets Dashboards, moniteurs Alerting et détecteurs Security Analytics.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

OS_HOST="${OPENSEARCH_HOST:-https://localhost:9200}"
OS_USER="${OPENSEARCH_USERNAME:-admin}"
OS_PASS="${OPENSEARCH_PASSWORD:-${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}}"
DASHBOARDS_URL="${OPENSEARCH_DASHBOARDS_URL:-http://localhost:5601}"

if [[ -z "${OS_PASS}" ]]; then
  echo "Définir OPENSEARCH_PASSWORD ou OPENSEARCH_INITIAL_ADMIN_PASSWORD" >&2
  exit 1
fi

curl_os() {
  curl -ks -u "${OS_USER}:${OS_PASS}" "$@"
}

echo "==> Index template microcrm-security-events"
curl_os -X PUT "${OS_HOST}/_index_template/microcrm-security-events" \
  -H 'Content-Type: application/json' \
  --data-binary "@${SCRIPT_DIR}/index-template-security-events.json"

echo "==> Import saved objects (Dashboards)"
IMPORT_RESULT=$(curl -ks -u "${OS_USER}:${OS_PASS}" \
  -X POST "${DASHBOARDS_URL}/api/saved_objects/_import?overwrite=true" \
  -H 'osd-xsrf: true' \
  -H 'securitytenant: global' \
  --form "file=@${SCRIPT_DIR}/saved-objects.ndjson")
echo "${IMPORT_RESULT}" | head -c 500
echo

echo "==> Moniteurs Alerting"
MONITORS=$(python3 -c "import json; print(len(json.load(open('${SCRIPT_DIR}/alerting-monitors.json'))))" 2>/dev/null || echo 4)
for i in $(seq 0 $((MONITORS - 1))); do
  BODY=$(python3 -c "import json,sys; print(json.dumps(json.load(open('${SCRIPT_DIR}/alerting-monitors.json'))[int(sys.argv[1])]))" "$i")
  NAME=$(echo "${BODY}" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
  echo "  - ${NAME}"
  RESP=$(curl_os -X POST "${OS_HOST}/_plugins/_alerting/monitors" \
    -H 'Content-Type: application/json' \
    -d "${BODY}" 2>&1) || true
  if echo "${RESP}" | grep -qE '"_id"|"monitor_id"|already exists'; then
    echo "    OK"
  else
    echo "    Note: ${RESP}" | head -c 200
    echo
  fi
done

echo "==> Détecteurs Security Analytics (si plugin disponible)"
DETECTORS=$(python3 -c "import json; print(len(json.load(open('${SCRIPT_DIR}/security-analytics-detectors.json'))))" 2>/dev/null || echo 3)
for i in $(seq 0 $((DETECTORS - 1))); do
  BODY=$(python3 -c "import json,sys; print(json.dumps(json.load(open('${SCRIPT_DIR}/security-analytics-detectors.json'))[int(sys.argv[1])]))" "$i")
  NAME=$(echo "${BODY}" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
  echo "  - ${NAME}"
  RESP=$(curl_os -X POST "${OS_HOST}/_plugins/_security_analytics/detectors" \
    -H 'Content-Type: application/json' \
    -d "${BODY}" 2>&1) || true
  if echo "${RESP}" | grep -qE '"_id"|"detector_id"|already exists'; then
    echo "    OK"
  else
    echo "    (plugin absent ou format API différent — ignorable en dev)" | head -c 120
    echo " ${RESP}" | head -c 120
    echo
  fi
done

echo "==> Terminé. Ouvrir Dashboards → MicroCRM SOC"
if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
  echo "==> SLACK_WEBHOOK_URL défini — exécuter: ./observability/opensearch/setup-slack-destination.sh"
fi
