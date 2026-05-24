#!/usr/bin/env bash
# Exporte les métriques DORA depuis l'API GitHub Actions (nécessite gh CLI authentifié).
# Usage: ./scripts/export-dora-metrics.sh [-o fichier.md] [-d jours] [owner/repo]
set -euo pipefail

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

if ! command -v gh >/dev/null 2>&1; then
  echo "Erreur: installer GitHub CLI (gh) et exécuter gh auth login" >&2
  exit 1
fi

SINCE=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"${DAYS}"d +%Y-%m-%dT%H:%M:%SZ)

report() {
  if [[ -n "${OUTPUT}" ]]; then
    mkdir -p "$(dirname "${OUTPUT}")"
    tee "${OUTPUT}"
  else
    cat
  fi
}

RUNS_JSON=$(gh api "repos/${REPO}/actions/runs?per_page=100" --paginate 2>/dev/null | python3 <<'PY' || echo "[]"
import json, sys
runs = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        data = json.loads(line)
    except json.JSONDecodeError:
        continue
    batch = data.get("workflow_runs", [])
    if isinstance(batch, list):
        runs.extend(batch)
seen = set()
unique = []
for r in runs:
    rid = r.get("id")
    if rid not in seen:
        seen.add(rid)
        unique.append(r)
print(json.dumps(unique))
PY
)

export REPO DAYS SINCE
METRICS=$(echo "${RUNS_JSON}" | python3 <<'PY'
import json, os, sys
from datetime import datetime

runs = json.load(sys.stdin)
since_str = os.environ.get("SINCE", "")
days = int(os.environ.get("DAYS", "28"))
repo = os.environ.get("REPO", "")

def parse_dt(s):
    if not s:
        return None
    return datetime.fromisoformat(s.replace("Z", "+00:00"))

since = parse_dt(since_str) if since_str else None
filtered = []
for r in runs:
    created = parse_dt(r.get("created_at"))
    if since and created and created < since:
        continue
    filtered.append(r)

ci = [r for r in filtered if r.get("name") == "CI"]
cd = [r for r in filtered if r.get("name") == "CD"]
nightly = [r for r in filtered if r.get("name") == "Nightly"]

def avg_minutes(runs):
    deltas = []
    for r in runs:
        if r.get("conclusion") not in ("success", "failure", "cancelled"):
            continue
        a = parse_dt(r.get("run_started_at"))
        b = parse_dt(r.get("updated_at"))
        if a and b and b > a:
            deltas.append((b - a).total_seconds() / 60)
    return round(sum(deltas) / len(deltas), 1) if deltas else None

weeks = max(1, days / 7)
cd_success = [r for r in cd if r.get("conclusion") == "success"]
deploy_freq = round(len(cd_success) / weeks, 2)

cd_total = len([r for r in cd if r.get("conclusion")])
cd_fail = len([r for r in cd if r.get("conclusion") == "failure"])
cfr = round(100 * cd_fail / cd_total, 1) if cd_total else 0

ci_main_success = [r for r in ci if r.get("head_branch") == "main" and r.get("conclusion") == "success"]
lead_time = avg_minutes(ci_main_success)

ci_main = sorted([r for r in ci if r.get("head_branch") == "main"], key=lambda x: x.get("created_at", ""))
mttr_samples = []
for i, r in enumerate(ci_main):
    if r.get("conclusion") != "failure":
        continue
    fail_end = parse_dt(r.get("updated_at"))
    for r2 in ci_main[i + 1 :]:
        if r2.get("conclusion") == "success":
            ok_start = parse_dt(r2.get("run_started_at"))
            if fail_end and ok_start and ok_start > fail_end:
                mttr_samples.append((ok_start - fail_end).total_seconds() / 3600)
            break
mttr = round(sum(mttr_samples) / len(mttr_samples), 2) if mttr_samples else None

ci_fail_rate = round(100 * len([r for r in ci if r.get("conclusion") == "failure"]) / len(ci), 1) if ci else 0

print(json.dumps({
    "period_days": days,
    "repo": repo,
    "lead_time_minutes": lead_time,
    "deployment_frequency_per_week": deploy_freq,
    "mttr_hours": mttr,
    "change_failure_rate_pct": cfr,
    "ci_failure_rate_pct": ci_fail_rate,
    "ci_runs": len(ci),
    "cd_runs": len(cd),
    "nightly_runs": len(nightly),
}))
PY
)

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
