#!/usr/bin/env bash
# Rapport de santé MicroCRM + OpenSearch (revue hebdomadaire type Maria).
set -euo pipefail

OS_HOST="${OPENSEARCH_HOST:-https://localhost:9200}"
OS_USER="${OPENSEARCH_USERNAME:-admin}"
OS_PASS="${OPENSEARCH_PASSWORD:-${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}}"
REPO="${GITHUB_REPOSITORY:-laurentcoufinal/projet9}"

echo "=== MicroCRM — état de santé $(date -u +%Y-%m-%dT%H:%MZ) ==="
echo

if [[ -n "${OS_PASS}" ]]; then
  echo "## OpenSearch"
  HEALTH=$(curl -ks -u "${OS_USER}:${OS_PASS}" "${OS_HOST}/_cluster/health" 2>/dev/null || echo "{}")
  echo "${HEALTH}" | python3 -c "
import json,sys
h=json.load(sys.stdin)
print(f\"  Cluster: {h.get('status','unknown')} — nodes {h.get('number_of_nodes','?')}\")
" 2>/dev/null || echo "  Cluster: indisponible"
  for idx in microcrm-defects microcrm-security-events microcrm-server-state; do
    COUNT=$(curl -ks -u "${OS_USER}:${OS_PASS}" "${OS_HOST}/${idx}/_count" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('count','?'))" 2>/dev/null || echo "?")
    echo "  Index ${idx}: ${COUNT} documents"
  done
else
  echo "## OpenSearch — ignoré (OPENSEARCH_PASSWORD non défini)"
fi
echo

echo "## Application (local)"
if curl -sf http://localhost:8080/persons >/dev/null 2>&1; then
  echo "  API back : OK (http://localhost:8080/persons)"
else
  echo "  API back : indisponible"
fi
if curl -sfL -o /dev/null http://localhost:80/ 2>/dev/null || curl -sfk -o /dev/null https://localhost:443/ 2>/dev/null; then
  echo "  Front    : OK"
else
  echo "  Front    : indisponible"
fi
echo

if command -v gh >/dev/null 2>&1; then
  echo "## Derniers runs GitHub Actions"
  gh run list --repo "${REPO}" --limit 5 2>/dev/null || echo "  (gh non authentifié)"
else
  echo "## GitHub Actions — installer gh pour le détail"
fi
echo
echo "DORA détaillé : ./scripts/export-dora-metrics.sh"
