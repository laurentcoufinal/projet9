#!/usr/bin/env bash
# Envoie une notification vers Slack (Incoming Webhook).
# Usage: notify-slack.sh "Titre" "Message" [URL optionnelle]
set -euo pipefail

TITLE="${1:-MicroCRM alert}"
MESSAGE="${2:-}"
LINK="${3:-}"

if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  echo "SLACK_WEBHOOK_URL non défini — notification ignorée." >&2
  exit 0
fi

TEXT="${TITLE}"
if [[ -n "${MESSAGE}" ]]; then
  TEXT="${TEXT}"$'\n'"${MESSAGE}"
fi
if [[ -n "${LINK}" ]]; then
  TEXT="${TEXT}"$'\n'"<${LINK}|Voir le détail>"
fi

PAYLOAD=$(python3 -c "import json,sys; print(json.dumps({'text': sys.argv[1]}))" "${TEXT}")

curl -fsS -X POST "${SLACK_WEBHOOK_URL}" \
  -H 'Content-Type: application/json' \
  -d "${PAYLOAD}"
