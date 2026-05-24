# Démo monitoring — réunion Maria

Procédure pour présenter la stack **ELK équivalente** (OpenSearch + Fluent Bit + Dashboards) et les alertes **Slack**.

## Prérequis

- Docker et Docker Compose
- Fichier `.env` à la racine avec `OPENSEARCH_INITIAL_ADMIN_PASSWORD`
- Secret `SLACK_WEBHOOK_URL` (Incoming Webhook) pour la démo des alertes

## 1. Démarrer les stacks

```bash
# Racine du dépôt
docker compose -f docker-compose-opensearch.yml up -d
cd P7-FSJA && docker compose up -d
```

Attendre le cluster `green` ou `yellow` :

```bash
export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD .env | cut -d= -f2-)"
curl -ks -u "admin:${OPENSEARCH_PASSWORD}" https://localhost:9200/_cluster/health?pretty
```

## 2. Initialiser le SIEM

```bash
chmod +x observability/opensearch/setup-siem.sh observability/opensearch/setup-slack-destination.sh
./observability/opensearch/setup-siem.sh
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."   # ne pas committer
./observability/opensearch/setup-slack-destination.sh
```

## 3. Dashboard MicroCRM SOC

Ouvrir http://localhost:5601 → **MicroCRM SOC**

| Panneau | Indicateur Maria |
|---------|------------------|
| Erreurs par code HTTP | Erreurs applicatives (`microcrm-defects`) |
| Santé services | Disponibilité conteneurs |
| Accès API par outcome | Volumétrie / succès vs erreurs client/serveur |

Visualisations complémentaires (Discover) :

- Index `microcrm-security-events` : histogramme sur `timestamp` → **pics d’activité**
- Index `microcrm-defects` : courbe 5xx → **pics d’erreurs**

## 4. Générer du trafic de test

```bash
curl http://localhost:8080/persons
curl -X POST http://localhost:8080/persons -H 'Content-Type: application/json' \
  -d '{"firstName":"Demo","lastName":"Maria","email":"invalid"}'   # 400 → defects
```

## 5. Alertes Slack

| Moniteur | Seuil | Slack |
|----------|-------|-------|
| spike 5xx | > 10 / 5 min | `[P0] MicroCRM spike 5xx` |
| health down | ≥ 1 / 2 min | `[P0] MicroCRM service unhealthy` |
| spike 4xx | > 50 / 5 min | `[P1] MicroCRM spike 4xx` |
| mass DELETE | > 20 / 10 min | `[P1] MicroCRM mass DELETE` |

Échec CI/nightly : notification automatique via `scripts/notify-slack.sh` dans GitHub Actions.

## 6. Rapport de santé et DORA

```bash
./observability/scripts/health-status.sh
./scripts/export-dora-metrics.sh -o P7-FSJA/reports/dora-latest.md
```
