#!/usr/bin/env bash
# Exporte les métriques DORA depuis l'API GitHub Actions (PAT ou gh CLI).
# Usage: ./scripts/export-dora-metrics.sh [-o fichier.md] [-d jours] [owner/repo]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DORA_COMPUTE="${REPO_ROOT}/scripts/lib/dora_compute.py"

REPO="${GITHUB_REPOSITORY:-laurentcoufinal/projet9}"
OUTPUT=""
DAYS=28

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output) OUTPUT="$2"; shift 2 ;;
    -d|--days) DAYS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [-o rapport.md] [-d 28] [owner/repo]"
      exit 0
      ;;
    *)
      REPO="$1"
      shift
      ;;
  esac
done

if [[ -z "${GITHUB_TOKEN:-}" ]] && ! command -v gh >/dev/null 2>&1; then
  echo "Erreur: définir GITHUB_TOKEN ou installer gh CLI (gh auth login)" >&2
  exit 1
fi

report() {
  if [[ -n "${OUTPUT}" ]]; then
    mkdir -p "$(dirname "${OUTPUT}")"
    tee "${OUTPUT}"
  else
    cat
  fi
}

RUNS_JSON="$(python3 "${DORA_COMPUTE}" fetch --repo "${REPO}" --token "${GITHUB_TOKEN:-}")"
METRICS="$(echo "${RUNS_JSON}" | python3 "${DORA_COMPUTE}" metrics --repo "${REPO}" --days "${DAYS}")"

echo "${METRICS}" | python3 -c "
import json, sys
from datetime import datetime, timezone
m = json.load(sys.stdin)
now = datetime.now(timezone.utc).strftime('%Y-%m-%d')
lt = m.get('lead_time_minutes')
mttr = m.get('mttr_hours')
md = f'''# Métriques DORA — {m.get('repo', '')}

Période : **{m.get('period_days', 28)} jours** — généré le {now}.

| Métrique DORA | Valeur observée | Commentaire |
|---------------|-----------------|-------------|
| **Lead Time for Changes** | {lt if lt is not None else 'n/a'} min | Proxy : durée moyenne CI réussie sur \`main\` |
| **Deployment Frequency** | {m.get('deployment_frequency_per_week', 0)} / semaine | Workflows CD réussis |
| **MTTR** | {mttr if mttr is not None else 'n/a'} h | Délai moyen entre échec CI et succès suivant sur \`main\` |
| **Change Failure Rate** | {m.get('change_failure_rate_pct', 0)} % | Échecs CD / total runs CD |

## KPI pipeline

| KPI | Valeur |
|-----|--------|
| Runs CI | {m.get('ci_runs', 0)} |
| Runs CD | {m.get('cd_runs', 0)} |
| Runs Nightly | {m.get('nightly_runs', 0)} |
| Taux échec CI | {m.get('ci_failure_rate_pct', 0)} % |
'''
print(md)
" | report
