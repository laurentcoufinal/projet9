#!/usr/bin/env bash
# Provisionne index template, objets Dashboards, moniteurs Alerting et détecteurs Security Analytics.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

load_dotenv() {
  local env_file="$1"
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
    return 0
  fi
  return 1
}

load_dotenv "${REPO_ROOT}/.env" || load_dotenv "${SCRIPT_DIR}/.env" || true

OS_HOST="${OPENSEARCH_HOST:-https://localhost:9200}"
OS_USER="${OPENSEARCH_USERNAME:-admin}"
OS_PASS="${OPENSEARCH_PASSWORD:-${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}}"
DASHBOARDS_URL="${OPENSEARCH_DASHBOARDS_URL:-http://localhost:5601}"

if [[ -z "${OS_PASS}" ]]; then
  echo "Définir OPENSEARCH_PASSWORD ou OPENSEARCH_INITIAL_ADMIN_PASSWORD" >&2
  echo "Astuce : créer ${REPO_ROOT}/.env (voir .env.example) ou exporter la variable avant d'exécuter le script." >&2
  exit 1
fi

curl_os() {
  curl -ks -u "${OS_USER}:${OS_PASS}" "$@"
}

echo "==> Index template microcrm-security-events"
curl_os -X PUT "${OS_HOST}/_index_template/microcrm-security-events" \
  -H 'Content-Type: application/json' \
  --data-binary "@${SCRIPT_DIR}/index-template-security-events.json"

echo "==> Index template microcrm-defects"
curl_os -X PUT "${OS_HOST}/_index_template/microcrm-defects" \
  -H 'Content-Type: application/json' \
  --data-binary "@${SCRIPT_DIR}/index-template-defects.json"

echo "==> Index template microcrm-server-state"
curl_os -X PUT "${OS_HOST}/_index_template/microcrm-server-state" \
  -H 'Content-Type: application/json' \
  --data-binary "@${SCRIPT_DIR}/index-template-server-state.json"

echo "==> Bootstrap index SIEM (documents init pour Dashboards)"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
curl_os -X POST "${OS_HOST}/microcrm-defects/_doc/bootstrap?refresh=wait_for" \
  -H 'Content-Type: application/json' \
  -d "{\"timestamp\":\"${TS}\",\"requestId\":\"bootstrap\",\"level\":\"INFO\",\"message\":\"SIEM bootstrap\",\"path\":\"/bootstrap\",\"method\":\"GET\",\"status\":0,\"bootstrap\":true}"
curl_os -X POST "${OS_HOST}/microcrm-security-events/_doc/bootstrap?refresh=wait_for" \
  -H 'Content-Type: application/json' \
  -d "{\"timestamp\":\"${TS}\",\"requestId\":\"bootstrap\",\"eventCategory\":\"security\",\"eventType\":\"access\",\"method\":\"GET\",\"path\":\"/bootstrap\",\"status\":200,\"outcome\":\"success\",\"bootstrap\":true}"
curl_os -X POST "${OS_HOST}/microcrm-server-state/_doc/bootstrap?refresh=wait_for" \
  -H 'Content-Type: application/json' \
  -d "{\"@timestamp\":\"${TS}\",\"event_type\":\"health\",\"source\":\"bootstrap\",\"status\":\"up\",\"bootstrap\":true}"

echo "==> Import saved objects (Dashboards)"
IMPORT_RESULT=$(curl -ks -u "${OS_USER}:${OS_PASS}" \
  -X POST "${DASHBOARDS_URL}/api/saved_objects/_import?overwrite=true" \
  -H 'osd-xsrf: true' \
  -H 'securitytenant: global' \
  --form "file=@${SCRIPT_DIR}/saved-objects.ndjson")
echo "${IMPORT_RESULT}" | head -c 500
echo

echo "==> Rafraîchissement des index patterns Dashboards"
refresh_index_pattern_fields() {
  local pattern_id="$1"
  local pattern_title="$2"
  python3 - "${pattern_id}" "${pattern_title}" "${DASHBOARDS_URL}" "${OS_USER}" "${OS_PASS}" <<'PY'
import json, subprocess, sys

pattern_id, pattern_title, dashboards_url, user, password = sys.argv[1:6]

def curl(args):
    cmd = ["curl", "-ks", "-u", f"{user}:{password}", *args]
    return subprocess.check_output(cmd, text=True)

fields_raw = curl([
    f"{dashboards_url}/api/index_patterns/_fields_for_wildcard",
    "-G",
    "--data-urlencode", f"pattern={pattern_title}",
    "-H", "osd-xsrf: true",
    "-H", "securitytenant: global",
])
fields_payload = json.loads(fields_raw)
field_list = fields_payload.get("fields", [])

current_raw = curl([
    f"{dashboards_url}/api/saved_objects/index-pattern/{pattern_id}",
    "-H", "osd-xsrf: true",
    "-H", "securitytenant: global",
])
current = json.loads(current_raw)
attrs = dict(current.get("attributes", {}))
attrs["fields"] = json.dumps(field_list)

update_body = json.dumps({"attributes": attrs})
subprocess.check_output([
    "curl", "-ks", "-u", f"{user}:{password}",
    "-X", "PUT",
    f"{dashboards_url}/api/saved_objects/index-pattern/{pattern_id}",
    "-H", "Content-Type: application/json",
    "-H", "osd-xsrf: true",
    "-H", "securitytenant: global",
    "-d", update_body,
], text=True)
print(len(field_list))
PY
}

for entry in \
  "microcrm-defects-pattern:microcrm-defects*" \
  "microcrm-server-state-pattern:microcrm-server-state*" \
  "microcrm-security-events-pattern:microcrm-security-events*" \
  "security-auditlog-pattern:security-auditlog-*"; do
  pattern_id="${entry%%:*}"
  pattern_title="${entry#*:}"
  field_count="$(refresh_index_pattern_fields "${pattern_id}" "${pattern_title}" 2>/dev/null || echo 0)"
  echo "  - ${pattern_id}: ${field_count} champs"
done

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
