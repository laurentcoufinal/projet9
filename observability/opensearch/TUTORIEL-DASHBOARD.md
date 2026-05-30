# Tutoriel — Configuration du dashboard OpenSearch MicroCRM SOC

Guide pas-à-pas pour démarrer la stack observabilité, alimenter les index SIEM et afficher le tableau de bord **MicroCRM SOC**.

**Références :** [documentation-technique.md](../../P7-FSJA/documentation-technique.md) (§3.4, §6.2), [information_logge.md](../../information_logge.md), [DEMO-MARIA.md](DEMO-MARIA.md).

---

## En 30 secondes

```bash
cp .env.example .env          # adapter le mot de passe
docker compose -f docker-compose-opensearch.yml up -d
cd P7-FSJA && docker compose --env-file ../.env up -d && cd ..
export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD .env | cut -d= -f2-)"
./observability/opensearch/setup-siem.sh
```

Ouvrir http://localhost:5601 → **Dashboards** → **MicroCRM SOC**.

---

## Architecture des données

| Index | Source | Contenu |
|-------|--------|---------|
| `microcrm-defects` | Backend Spring Boot | Erreurs API 4xx/5xx + `requestId` |
| `microcrm-security-events` | Backend + Fluent Bit + CI | Journal d'accès API, événements pipeline |
| `microcrm-server-state` | Fluent Bit | Logs conteneurs, health TCP, métriques host |
| `security-auditlog-*` | OpenSearch Security | Audit admin cluster |

Le script [`setup-siem.sh`](setup-siem.sh) importe automatiquement les index patterns, les 3 visualisations et le dashboard depuis [`saved-objects.ndjson`](saved-objects.ndjson). **Aucune création manuelle dans l'UI n'est nécessaire.**

---

## Étape 1 — Prérequis

| Prérequis | Détail |
|-----------|--------|
| Docker + Compose | Engine ≥ 24 |
| Fichier `.env` | Copier [`.env.example`](../../.env.example) → `.env` à la **racine** du dépôt |
| Mot de passe | `OPENSEARCH_INITIAL_ADMIN_PASSWORD` : majuscule, minuscule, chiffre, caractère spécial, ≥ 8 caractères |
| Alignement | `OPENSEARCH_PASSWORD` = **même valeur** que `OPENSEARCH_INITIAL_ADMIN_PASSWORD` |

**Action manuelle obligatoire :** créer le fichier `.env` (ne jamais le committer).

---

## Étape 2 — Démarrer les stacks

L'ordre compte : Fluent Bit doit écouter sur le port `24224` avant d'activer le driver de logs optionnel.

```bash
# Depuis la racine du dépôt

# 1. Stack observabilité (OpenSearch + Dashboards + Fluent Bit)
docker compose -f docker-compose-opensearch.yml up -d

# 2. Attendre cluster green ou yellow
export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD .env | cut -d= -f2-)"
curl -ks -u "admin:${OPENSEARCH_PASSWORD}" https://localhost:9200/_cluster/health?pretty

# 3. Application MicroCRM (indexation OpenSearch activée par défaut)
cd P7-FSJA
docker compose --env-file ../.env up -d
cd ..
```

| Service | URL |
|---------|-----|
| OpenSearch API | https://localhost:9200 |
| OpenSearch Dashboards | http://localhost:5601 (login `admin` / mot de passe `.env`) |
| Fluent Bit (forward) | `host:24224` |

### Optionnel — logs conteneurs vers Fluent Bit

Sans cette option, le backend indexe quand même `microcrm-defects` et `microcrm-security-events`. Seul `microcrm-server-state` (logs/health Fluent Bit) sera moins alimenté.

```bash
cd P7-FSJA
docker compose -f docker-compose.yml -f docker-compose.fluent-logs.yml --env-file ../.env up -d
cd ..
```

Sur Linux/WSL, vérifier que `FLUENTD_ADDRESS=172.17.0.1:24224` est défini dans `.env`.

---

## Étape 3 — Initialiser le SIEM et importer le dashboard

```bash
# Depuis la racine du dépôt
chmod +x observability/opensearch/setup-siem.sh
export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD .env | cut -d= -f2-)"
./observability/opensearch/setup-siem.sh
```

Ce script configure :

- Le template d'index `microcrm-security-events`
- L'import du dashboard **MicroCRM SOC** + 4 index patterns
- Les 4 moniteurs Alerting (seuils documentation §6.2)
- Les détecteurs Security Analytics (optionnels, ignorables en dev)

**Résultat attendu :** message `Terminé. Ouvrir Dashboards → MicroCRM SOC`.

---

## Étape 4 — Ouvrir et lire le dashboard

1. Aller sur http://localhost:5601
2. Se connecter avec `admin` et le mot de passe du `.env`
3. Menu **Dashboards** (icône grille) → **MicroCRM SOC**

### Correspondance panneaux ↔ KPI

| Panneau | Index source | KPI (doc §6.2) |
|---------|--------------|----------------|
| Erreurs par code HTTP | `microcrm-defects` | Erreurs 5xx (< 10 / 5 min), Erreurs 4xx (< 50 / 5 min) |
| Santé services (health) | `microcrm-server-state` | Santé conteneurs (0 `down` / 2 min) |
| Accès API par outcome | `microcrm-security-events` | Volume requêtes API, succès vs erreurs client/serveur |

### Champs utiles par index

| Index | Champs clés |
|-------|-------------|
| `microcrm-defects` | `requestId`, `status`, `path`, `method`, `timestamp` |
| `microcrm-security-events` | `requestId`, `outcome`, `clientIp`, `method`, `path`, `sensitive` |
| `microcrm-server-state` | `event_type` (log / health / metrics), `source`, `status` |

**Astuce UI :** régler la plage temporelle en haut à droite sur **Last 15 minutes** ou **Last 24 hours**, puis cliquer **Refresh**.

---

## Étape 5 — Générer des données de test

```bash
# Requête OK → microcrm-security-events (outcome: success)
curl http://localhost:8080/persons

# Erreur 400 → microcrm-defects + microcrm-security-events (client_error)
curl -X POST http://localhost:8080/persons \
  -H 'Content-Type: application/json' \
  -d '{"firstName":"Demo","lastName":"Test","email":"invalid"}'
```

### Vérifier que les index reçoivent des documents

```bash
curl -ks -u "admin:${OPENSEARCH_PASSWORD}" \
  "https://localhost:9200/microcrm-security-events/_count?pretty"
curl -ks -u "admin:${OPENSEARCH_PASSWORD}" \
  "https://localhost:9200/microcrm-defects/_count?pretty"
curl -ks -u "admin:${OPENSEARCH_PASSWORD}" \
  "https://localhost:9200/microcrm-server-state/_count?pretty"
```

Actualiser le dashboard : les panneaux doivent afficher des barres ou des parts de camembert.

### Corréler un incident via `requestId`

1. Récupérer le `requestId` (header `X-Request-Id` dans les DevTools réseau du navigateur).
2. **Discover** → index pattern `microcrm-security-events*` → filtre `requestId:"<uuid>"`.
3. Même recherche dans `microcrm-defects*` si une erreur s'est produite.
4. Optionnel : `microcrm-server-state*` autour du même timestamp.

---

## Étape 6 — Alertes et compléments (optionnel)

### Slack — moniteurs P0

```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."   # ne pas committer
export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD .env | cut -d= -f2-)"
chmod +x observability/opensearch/setup-slack-destination.sh
./observability/opensearch/setup-slack-destination.sh
```

| Moniteur | Seuil | Priorité |
|----------|-------|----------|
| spike 5xx | > 10 / 5 min | P0 |
| health down | ≥ 1 / 2 min | P0 |
| spike 4xx | > 50 / 5 min | P1 |
| mass DELETE | > 20 / 10 min | P1 |

Canal recommandé : `#orion-microcrm-alerts`.

### Événements CI

Simuler un événement pipeline (index `microcrm-security-events`, `eventType: ci`) :

```bash
chmod +x observability/opensearch/index-ci-event.sh
./observability/opensearch/index-ci-event.sh sonar.quality_gate failure
```

### Rapport de santé

```bash
chmod +x observability/scripts/health-status.sh
./observability/scripts/health-status.sh
```

---

## Dépannage

| Symptôme | Cause probable | Solution |
|----------|----------------|----------|
| Dashboard vide | Pas de trafic API ou stack back arrêtée | Étape 5 — générer du trafic avec `curl` |
| Panneau « Santé services » vide | Fluent Bit sans logs conteneurs | Activer `docker-compose.fluent-logs.yml` (étape 2) |
| `setup-siem.sh` échoue (auth) | Mot de passe `.env` incorrect | Vérifier `OPENSEARCH_PASSWORD` exporté |
| Import dashboard échoue | Dashboards pas encore prêt | Attendre 1–2 min après `docker compose up` |
| Index absents | Backend sans OpenSearch | Vérifier `OPENSEARCH_ENABLED=true` dans `P7-FSJA/docker-compose.yml` |
| Notification Slack ignorée | Secret absent | Configurer `SLACK_WEBHOOK_URL` avant `setup-slack-destination.sh` |

---

## Actions manuelles vs automatiques

| Action | Manuelle ? |
|--------|------------|
| Créer `.env` | Oui |
| Démarrer Docker Compose | Oui |
| Lancer `setup-siem.sh` | Oui (1 commande) |
| Créer index patterns / visualisations / dashboard | Non — import automatique |
| Créer moniteurs Alerting | Non — script automatique |
| Configurer webhook Slack | Oui (optionnel) |
| Générer trafic de test | Oui (pour voir des données) |

---

## Aller plus loin

- **Démo présentation :** [DEMO-MARIA.md](DEMO-MARIA.md)
- **Référence champs et requêtes DSL :** [information_logge.md](../../information_logge.md)
- **Configuration SIEM complète :** [README.md](README.md)
