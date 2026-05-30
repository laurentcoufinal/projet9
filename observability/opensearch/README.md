# SIEM OpenSearch — MicroCRM

**Tutoriel pas-à-pas :** [TUTORIEL-DASHBOARD.md](TUTORIEL-DASHBOARD.md) — configuration du dashboard **MicroCRM SOC** en local.

## Contenu

| Fichier | Rôle |
|---------|------|
| `TUTORIEL-DASHBOARD.md` | Guide débutant — stack, index, dashboard, KPI, dépannage |
| `setup-siem.sh` | Index template, import Dashboards, moniteurs Alerting, détecteurs Security Analytics |
| `saved-objects.ndjson` | Index patterns + dashboard **MicroCRM SOC** |
| `alerting-monitors.json` | Spike 5xx, spike 4xx, health down, suppressions massives DELETE |
| `security-analytics-detectors.json` | Détecteurs bucket-level (5xx, 4xx, volume IP) |
| `index-template-security-events.json` | Mapping `microcrm-security-events` |
| `index-ci-event.sh` | Publication événements CI vers OpenSearch |
| `setup-slack-destination.sh` | Destination webhook Slack + actions sur moniteurs P0 |
| `DEMO-MARIA.md` | Procédure démo monitoring pour Maria |

## Prérequis

Stack OpenSearch démarrée, `.env` avec `OPENSEARCH_INITIAL_ADMIN_PASSWORD`.

```bash
export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD .env | cut -d= -f2-)"
chmod +x observability/opensearch/setup-siem.sh observability/opensearch/index-ci-event.sh
./observability/opensearch/setup-siem.sh
```

Dashboards : http://localhost:5601 → **MicroCRM SOC**

## Alertes P0

| Moniteur | Seuil | Index |
|----------|-------|-------|
| `microcrm-defects-high-5xx` | > 10 erreurs 5xx / 5 min | `microcrm-defects` |
| `microcrm-defects-high-4xx` | > 50 erreurs 4xx / 5 min | `microcrm-defects` |
| `microcrm-server-health-down` | ≥ 1 health `down` / 2 min | `microcrm-server-state` |
| `microcrm-security-mass-delete` | > 20 DELETE réussis / 10 min | `microcrm-security-events` |

### Slack (recommandé)

```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."   # ne pas committer
export OPENSEARCH_PASSWORD="..."
./observability/opensearch/setup-slack-destination.sh
```

Crée la destination Alerting et attache les notifications aux 4 moniteurs P0.

Alternative manuelle : Dashboards → **Alerting** → **Destinations** → **Create destination** → custom webhook → URL Slack.

### CI GitHub

Secret dépôt : `SLACK_WEBHOOK_URL`. Les workflows `ci.yml` et `nightly.yml` appellent `scripts/notify-slack.sh` en cas d'échec.

## Événements CI

En local (OpenSearch up) :

```bash
./observability/opensearch/index-ci-event.sh sonar.quality_gate failure
```

La CI GitHub appelle ce script en `continue-on-error` si OpenSearch n’est pas joignable.

Configurer dans GitHub (optionnel) : variable `OPENSEARCH_URL`, secret `OPENSEARCH_PASSWORD`.

## Audit OpenSearch

Les nœuds OpenSearch activent `plugins.security.audit` → index `security-auditlog-*`.  
Créer un index pattern `security-auditlog-*` dans Dashboards (inclus dans `saved-objects.ndjson` après `setup-siem.sh`).
