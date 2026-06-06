#!/usr/bin/env bash
set -euo pipefail

SYNC_SCRIPT="/app/sync-dora-from-github.sh"
DAYS="${DORA_SYNC_DAYS:-90}"
CRON_SCHEDULE="${DORA_SYNC_CRON:-0 22 * * *}"

if [[ ! -x "${SYNC_SCRIPT}" ]]; then
  chmod +x "${SYNC_SCRIPT}" 2>/dev/null || true
fi

echo "==> DORA sync — backfill initial (${DAYS} jours)"
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "GITHUB_TOKEN absent — sync planifiée uniquement après configuration du PAT dans .env"
else
  "${SYNC_SCRIPT}" -d "${DAYS}" || echo "Sync initiale échouée (voir logs ci-dessus)"
fi

echo "${CRON_SCHEDULE} ${SYNC_SCRIPT} -d ${DAYS} >> /proc/1/fd/1 2>&1" > /crontab
echo "==> Planification cron: ${CRON_SCHEDULE} (UTC)"
exec /usr/local/bin/supercronic /crontab
