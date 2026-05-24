#!/usr/bin/env bash
# Crée une destination Alerting OpenSearch (webhook Slack) et attache les actions aux moniteurs P0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_HOST="${OPENSEARCH_HOST:-https://localhost:9200}"
OS_USER="${OPENSEARCH_USERNAME:-admin}"
OS_PASS="${OPENSEARCH_PASSWORD:-${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}}"
DEST_NAME="${SLACK_DESTINATION_NAME:-slack-microcrm-alerts}"

if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  echo "Définir SLACK_WEBHOOK_URL (Incoming Webhook Slack)." >&2
  exit 1
fi
if [[ -z "${OS_PASS}" ]]; then
  echo "Définir OPENSEARCH_PASSWORD ou OPENSEARCH_INITIAL_ADMIN_PASSWORD." >&2
  exit 1
fi

curl_os() { curl -ks -u "${OS_USER}:${OS_PASS}" "$@"; }

echo "==> Destination Slack (custom_webhook)"
DEST_BODY=$(python3 -c "
import json, os
print(json.dumps({
  'name': os.environ['DEST_NAME'],
  'type': 'custom_webhook',
  'config': {'url': os.environ['SLACK_WEBHOOK_URL']}
}))
")

DEST_RESP=$(curl_os -X POST "${OS_HOST}/_plugins/_alerting/destinations" \
  -H 'Content-Type: application/json' -d "${DEST_BODY}" 2>&1) || true

DEST_ID=$(echo "${DEST_RESP}" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get('_id', d.get('destination_id', '')))
except Exception:
    print('')
" 2>/dev/null || echo "")

if [[ -z "${DEST_ID}" ]]; then
  echo "Recherche destination existante ${DEST_NAME}..."
  DEST_ID=$(curl_os "${OS_HOST}/_plugins/_alerting/destinations/_search" \
    -H 'Content-Type: application/json' \
    -d "{\"query\":{\"match\":{\"name\":\"${DEST_NAME}\"}}}" 2>/dev/null | python3 -c "
import json,sys
h=json.load(sys.stdin)
hits=h.get('hits',{}).get('hits',[])
print(hits[0]['_id'] if hits else '')
" 2>/dev/null || echo "")
fi

if [[ -z "${DEST_ID}" ]]; then
  echo "Impossible de créer ou trouver la destination. Réponse: ${DEST_RESP}" >&2
  exit 1
fi
echo "Destination ID: ${DEST_ID}"

attach_action() {
  local MONITOR_ID="$1"
  local TRIGGER_NAME="$2"
  local SEVERITY_LABEL="$3"
  local MONITOR_JSON
  MONITOR_JSON=$(curl_os "${OS_HOST}/_plugins/_alerting/monitors/${MONITOR_ID}" 2>/dev/null) || return 0
  echo "${MONITOR_JSON}" | python3 -c "
import json,sys,os
m=json.load(sys.stdin).get('monitor', json.load(sys.stdin))
dest_id=os.environ['DEST_ID']
trigger_name=os.environ['TRIGGER_NAME']
label=os.environ['SEVERITY_LABEL']
for t in m.get('triggers', []):
    if t.get('name')==trigger_name:
        t['actions']=[{
            'name': 'slack-notify',
            'destination_id': dest_id,
            'message_template': {
                'source': label + ' — monitor {{ctx.monitor.name}} — trigger ' + trigger_name,
                'lang': 'mustache'
            },
            'throttle_enabled': True,
            'throttle': {'value': 10, 'unit': 'MINUTES'}
        }]
        break
body={'name': m['name'], 'type': m['type'], 'monitor_type': m['monitor_type'],
      'enabled': m.get('enabled', True), 'schedule': m['schedule'],
      'inputs': m['inputs'], 'triggers': m['triggers']}
if m.get('ui_metadata'): body['ui_metadata']=m['ui_metadata']
print(json.dumps(body))
" DEST_ID="${DEST_ID}" TRIGGER_NAME="${TRIGGER_NAME}" SEVERITY_LABEL="${SEVERITY_LABEL}" > /tmp/monitor-update.json

  curl_os -X PUT "${OS_HOST}/_plugins/_alerting/monitors/${MONITOR_ID}" \
    -H 'Content-Type: application/json' \
    --data-binary @/tmp/monitor-update.json >/dev/null 2>&1 && echo "  OK ${TRIGGER_NAME}" || echo "  Note: mise à jour manuelle requise pour ${MONITOR_ID}"
}

echo "==> Rattachement actions Slack aux moniteurs"
MONITORS=$(curl_os "${OS_HOST}/_plugins/_alerting/monitors/_search?size=20" \
  -H 'Content-Type: application/json' -d '{"query":{"match_all":{}}}' 2>/dev/null) || echo "{}"

echo "${MONITORS}" | python3 -c "
import json,sys
h=json.load(sys.stdin)
for hit in h.get('hits',{}).get('hits',[]):
    src=hit.get('_source',{})
    name=src.get('name','')
    mid=hit['_id']
    triggers={t.get('name'): t for t in src.get('triggers',[])}
    mapping={
        'microcrm-defects-high-5xx': ('spike-5xx', '[P0] MicroCRM spike 5xx'),
        'microcrm-defects-high-4xx': ('spike-4xx', '[P1] MicroCRM spike 4xx'),
        'microcrm-server-health-down': ('service-down', '[P0] MicroCRM service unhealthy'),
        'microcrm-security-mass-delete': ('mass-delete', '[P1] MicroCRM mass DELETE'),
    }
    if name in mapping:
        tname, label = mapping[name]
        print(f'{mid}\t{tname}\t{label}')
" | while IFS=$'\t' read -r MID TNAME LABEL; do
  [[ -n "${MID}" ]] && attach_action "${MID}" "${TNAME}" "${LABEL}"
done

echo "==> Terminé. Tester avec une alerte ou: ./observability/opensearch/index-ci-event.sh test.slack manual"
