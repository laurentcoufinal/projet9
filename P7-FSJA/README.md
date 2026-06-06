<p align="center">
   <img src="./front/src/favicon.png" width="192px" />
</p>

# MicroCRM — Orion (P7 Full-Stack)

Application CRM simplifiée (Spring Boot 3 + Angular 18) avec chaîne **CI/CD**, conteneurisation **Docker Compose** et analyse **SonarCloud**.

![Page d'accueil](./misc/screenshots/screenshot_1.png)
![Édition de la fiche d'un individu](./misc/screenshots/screenshot_2.png)

## Sommaire

- [Démarrage complet (recommandé)](#démarrage-complet-recommandé)
- [Organisation du code](#organisation-du-code)
- [Démarrage local (sources)](#démarrage-local-sources)
- [Tests](#tests)
- [Observabilité (OpenSearch)](#observabilité-opensearch)
- [Docker & Docker Compose](#docker--docker-compose)
- [CI/CD GitHub Actions](#cicd-github-actions)
- [SonarCloud](#sonarcloud)
- [Déploiement (GHCR)](#déploiement-ghcr)
- [Documentation](#documentation)
- [Dépannage](#dépannage)

## Organisation du code

Ce monorepo contient :

| Répertoire | Stack |
|------------|-------|
| `back/` | Java 17, Spring Boot 3, Gradle, HSQLDB |
| `front/` | Angular 18.2, Karma/Jasmine |
| `misc/docker/` | Caddyfile, configuration Supervisor |
| `.github/workflows/` (racine du dépôt) | Pipelines CI/CD |

## Démarrage complet (recommandé)

Procédure pour lancer **MicroCRM + OpenSearch + dashboards SOC/DORA** depuis la racine du dépôt (`projet9/`).

### Prérequis

- Docker Engine ≥ 24, Docker Compose v2
- Fichier **`.env` à la racine** du dépôt (pas seulement `P7-FSJA/.env`) :

```shell
cp .env.example .env
# Éditer : OPENSEARCH_INITIAL_ADMIN_PASSWORD, OPENSEARCH_PASSWORD (même valeur)
# Optionnel mais recommandé pour le dashboard DORA :
# GITHUB_TOKEN=ghp_...  (PAT fine-grained : Actions read + Metadata read)
```

### Séquence

```shell
# 1. Stack observabilité (OpenSearch, Dashboards, Fluent Bit, dora-sync)
docker compose -f docker-compose-opensearch.yml up -d --build

# 2. Initialiser index, modèles SIEM et importer les dashboards
export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD .env | cut -d= -f2-)"
./observability/opensearch/setup-siem.sh

# 3. Application MicroCRM (indexation back vers OpenSearch)
cd P7-FSJA
docker compose --env-file ../.env up -d
```

| Service | URL |
|---------|-----|
| API MicroCRM | http://localhost:8080/persons |
| UI MicroCRM | https://localhost |
| OpenSearch API | https://localhost:9200 |
| OpenSearch Dashboards | http://localhost:5601 (dashboards **MicroCRM SOC** et **MicroCRM DORA**) |

Dans Dashboards, sélectionner la période **Last 90 days** pour le dashboard DORA.

Vérification rapide :

```shell
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'opensearch|fluent|dora|back|front'
docker logs dora-sync --tail 20
curl -f http://localhost:8080/persons
```

Pour le détail observabilité, voir [Observabilité (OpenSearch)](#observabilité-opensearch). Pour les sources sans Docker, voir [Démarrage local (sources)](#démarrage-local-sources).

## Démarrage local (sources)

### Backend

**Prérequis :** OpenJDK ≥ 17

```shell
cd back
chmod +x gradlew   # si nécessaire
./gradlew build
java -jar build/libs/microcrm-0.0.1-SNAPSHOT.jar
```

API : http://localhost:8080

### Frontend

**Prérequis :** Node.js ≥ 20, npm ≥ 10

```shell
cd front
npm install
npx @angular/cli serve
```

UI : http://localhost:4200

## Tests

### Backend

```shell
cd back
./gradlew test jacocoTestReport
```

Rapport JaCoCo : `back/build/reports/jacoco/test/html/index.html`

### Frontend

```shell
cd front
npm ci
npm run test:ci
```

En local, Chrome/Chromium doit être installé (`CHROME_BIN` si besoin).

## Observabilité (OpenSearch)

Stack OpenSearch **indépendante** de MicroCRM : [`docker-compose-opensearch.yml`](../docker-compose-opensearch.yml) à la racine du dépôt.

### Prérequis

1. Copier [`.env.example`](../.env.example) vers **`.env` à la racine** du dépôt (mot de passe admin OpenSearch + variables `OPENSEARCH_*`).
2. Définir `OPENSEARCH_PASSWORD` avec la **même valeur** que `OPENSEARCH_INITIAL_ADMIN_PASSWORD`.
3. Pour le dashboard **MicroCRM DORA** : ajouter `GITHUB_TOKEN` (PAT Actions read) et optionnellement `GITHUB_REPOSITORY`, `DORA_SYNC_DAYS`, `DORA_SYNC_CRON`.

Voir aussi la procédure unifiée : [Démarrage complet (recommandé)](#démarrage-complet-recommandé).

### Démarrage

Lancer **d'abord** la stack observabilité (Fluent Bit doit écouter sur le port `24224` avant MicroCRM) :

```shell
# Racine du dépôt — OpenSearch + Dashboards + Fluent Bit + dora-sync
docker compose -f docker-compose-opensearch.yml up -d --build

export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD .env | cut -d= -f2-)"
./observability/opensearch/setup-siem.sh

# Puis l'application MicroCRM
cd P7-FSJA
docker compose --env-file ../.env up -d

# (Optionnel) Logs conteneur vers Fluent Bit — uniquement si fluent-bit est déjà Up sur 24224 :
# docker compose -f docker-compose.yml -f docker-compose.fluent-logs.yml --env-file ../.env up -d
```

| Service | URL |
|---------|-----|
| OpenSearch API (node1) | https://localhost:9200 |
| OpenSearch Dashboards | http://localhost:5601 (dashboards **MicroCRM SOC** + **MicroCRM DORA**, utilisateur `admin`) |
| Fluent Bit (forward) | `host:24224` |
| `dora-sync` | Sync nocturne GitHub Actions → index `microcrm-dora-metrics` (`docker logs dora-sync`) |

Par défaut, les logs conteneur restent en **json-file** (arrêt Docker fiable). Le driver **fluentd** peut bloquer `docker stop` si Fluent Bit n'écoute pas sur `24224` — utiliser `docker-compose.fluent-logs.yml` seulement avec la stack observabilité démarrée. Sur Linux/WSL : `FLUENTD_ADDRESS=172.17.0.1:24224` dans `.env`.

### Index OpenSearch

| Index | Contenu | Source |
|-------|---------|--------|
| `microcrm-defects` | Erreurs applicatives 4xx/5xx + `requestId` | Client Java (`OpenSearchDefectLogger`) |
| `microcrm-server-state` | Santé (back Actuator, front, cluster OS), logs conteneurs, CPU/RAM/disque host | [Fluent Bit](../observability/fluent-bit/fluent-bit.conf) |
| `microcrm-security-events` | Journal d'accès API (IP, path, status, `requestId`), événements CI | `SecurityAccessLogFilter` + Fluent Bit + [index-ci-event.sh](../observability/opensearch/index-ci-event.sh) |
| `microcrm-dora-metrics` | Historique workflows GitHub Actions (Lead Time, CD, MTTR, CFR) | Conteneur `dora-sync` + [sync-dora-from-github.sh](../observability/opensearch/sync-dora-from-github.sh) |
| `security-auditlog-*` | Audit admin OpenSearch | Plugin Security (activé dans le compose) |

### SIEM (sécurité)

Après démarrage de la stack OpenSearch :

```shell
export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD ../.env | cut -d= -f2-)"
chmod +x ../observability/opensearch/setup-siem.sh
../observability/opensearch/setup-siem.sh
```

- Dashboards **MicroCRM SOC** et **MicroCRM DORA** : http://localhost:5601 (période **Last 90 days** pour DORA)
- Alertes : spike 5xx/4xx, health down, DELETE massifs (voir [observability/opensearch/README.md](../observability/opensearch/README.md))
- Export DORA Markdown : [`../scripts/export-dora-metrics.sh`](../scripts/export-dora-metrics.sh)
- Doc détaillée : [information logge.md](../information%20logge.md) à la racine du dépôt

Vérification rapide :

```shell
curl -ks -u "admin:VOTRE_MOT_DE_PASSE" \
  "https://localhost:9200/microcrm-server-state/_search?size=3&pretty"
```

### Traçage des requêtes

- Le front Angular génère un **UUID par requête HTTP** et l'envoie dans le header `X-Request-Id`.
- Le backend le reprend dans les logs (`%X{requestId}`) et l'associe aux erreurs indexées dans OpenSearch.
- Dans Dashboards : rechercher par champ `requestId` pour corréler une action UI et un défaut backend.

En développement local (`./gradlew bootRun`), le back cible `https://localhost:9200`. Depuis le conteneur `back`, la cible est `host.docker.internal:9200`.

## Docker & Docker Compose

### Prérequis

- Docker Engine ≥ 24
- Docker Compose v2

### Stack back + front (recommandé)

Avec la stack OpenSearch démarrée, utiliser `--env-file ../.env` pour activer l'indexation des défauts et accès API :

```shell
# Depuis ce répertoire (P7-FSJA) — voir aussi Démarrage complet (recommandé)
docker compose --env-file ../.env build
docker compose --env-file ../.env up -d
```

Sans OpenSearch (application seule) :

```shell
docker compose build
docker compose up -d
```

| Service | URL |
|---------|-----|
| API | http://localhost:8080/persons |
| UI | https://localhost (Caddy, certificat auto) |

```shell
docker compose down
```

### Vérification automatisée

```shell
./scripts/verify-docker.sh
```

### Profil standalone (un seul conteneur)

```shell
docker compose --profile standalone up -d
```

### Images individuelles (sans Compose)

```shell
docker build --target back -t orion-microcrm-back:latest .
docker build --target front -t orion-microcrm-front:latest .
docker run -it --rm -p 8080:8080 orion-microcrm-back:latest
docker run -it --rm -p 80:80 -p 443:443 orion-microcrm-front:latest
```

## CI/CD GitHub Actions

Dépôt : https://github.com/laurentcoufinal/projet9

| Workflow | Fichier | Déclencheur |
|----------|---------|-------------|
| **CI** | `.github/workflows/ci.yml` | Push / PR sur `main` |
| **CD** | `.github/workflows/cd.yml` | CI réussi sur `main`, ou manuel |
| **Nightly** | `.github/workflows/nightly.yml` | Cron 02:00 UTC, ou manuel |
| **Dependabot** | `.github/dependabot.yml` | PR hebdomadaires (Gradle, npm, Actions, Docker) → déclenche la CI |

### Étapes CI

1. Build & tests backend (Gradle + JaCoCo)
2. Build & tests frontend (Angular + couverture LCOV)
3. Analyse SonarCloud
4. Build des images Docker Compose

## SonarCloud

### Configuration initiale (une fois)

1. Créer un compte sur [SonarCloud](https://sonarcloud.io).
2. Importer le dépôt GitHub `projet9` et créer le projet (clé suggérée : `laurentcoufinal_projet9`).
3. Générer un token utilisateur.
4. Dans GitHub → **Settings → Secrets and variables → Actions**, ajouter :
   - `SONAR_TOKEN` : token SonarCloud

Le fichier [`sonar-project.properties`](sonar-project.properties) définit les chemins de sources et de couverture.

### Quality Gate (objectifs)

- Aucune nouvelle vulnérabilité Blocker / Critical
- Couverture backend ≥ 50 % (à affiner après le premier scan)
- Hotspots de sécurité revus

## Déploiement (GHCR)

Après un push réussi sur `main`, le workflow **CD** publie :

- `ghcr.io/laurentcoufinal/projet9/orion-microcrm-back:latest`
- `ghcr.io/laurentcoufinal/projet9/orion-microcrm-front:latest`

Sur une machine cible :

```shell
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/laurentcoufinal/projet9/orion-microcrm-back:latest
docker pull ghcr.io/laurentcoufinal/projet9/orion-microcrm-front:latest
cd P7-FSJA
docker compose up -d
```

## Documentation

| Document | Description |
|----------|-------------|
| [`documentation-technique.md`](documentation-technique.md) | Documentation complète (pipeline, sécurité, sauvegarde, KPI) — export PDF via Pandoc |
| [`../observability/opensearch/README.md`](../observability/opensearch/README.md) | Stack OpenSearch, SIEM, DORA |
| [`../observability/opensearch/TUTORIEL-DASHBOARD.md`](../observability/opensearch/TUTORIEL-DASHBOARD.md) | Tutoriel dashboard **MicroCRM SOC** |
| [`../observability/opensearch/DEMO-MARIA.md`](../observability/opensearch/DEMO-MARIA.md) | Démo monitoring + DORA |
| [`../cdc.md`](../cdc.md) | Cahier des charges |
| [`../documentation techinique.md`](../documentation%20techinique.md) | Template fourni |

## Sécurité des dépendances npm

Après `npm ci` dans `front/` :

```shell
cd front
npm audit
```

| Étape | Résultat typique |
|-------|------------------|
| Avant migration (Angular 17) | 44 vulnérabilités (28 High) |
| Après migration **Angular 18.2.14** + `npm audit fix` | 44 vulnérabilités (28 High signalées par l’audit npm) |

**Note :** `npm audit` propose souvent Angular **19** pour fermer les advisories (`<=18.2.14`). Le projet reste sur **18.2.14** (dernier patch de la branche 18.2.x). Les vulnérabilités **webpack-dev-server** / **esbuild** concernent surtout `ng serve` en développement ; la production utilise des assets compilés servis par Caddy.

Suivi continu : [`.github/dependabot.yml`](../.github/dependabot.yml) (mises à jour hebdomadaires npm).

Rapports détaillés : [`front/audit-avant.txt`](front/audit-avant.txt), [`front/audit-apres.txt`](front/audit-apres.txt).

## Dépannage

| Problème | Solution |
|----------|----------|
| `gradlew: Permission denied` | `chmod +x back/gradlew` |
| Karma : `No binary for ChromeHeadless` | Lancer `npm run test:ci` (installe Chrome automatiquement) ou `sudo apt install chromium-browser` puis `export CHROME_BIN=/usr/bin/chromium` |
| Front ne joint pas l’API | Vérifier que le back écoute sur `8080` ; l’URL API est dans `front/src/app/config.ts` |
| Healthcheck front en échec | Caddy redirige HTTP→HTTPS ; tester `curl -k https://localhost` |
| SonarCloud échoue en CI | Vérifier `SONAR_TOKEN` et la clé projet dans `sonar-project.properties` |
| Ports déjà utilisés | `docker compose down` ou changer les mappings dans `docker-compose.yml` |
| Dashboard DORA vide | Vérifier `GITHUB_TOKEN` dans `.env` racine, `docker logs dora-sync`, période **Last 90 days** dans Dashboards |
| `setup-siem.sh` échoue (connexion) | `export OPENSEARCH_PASSWORD` depuis `.env` ; OpenSearch doit être sur `https://localhost:9200` |
| Back n'indexe pas dans OpenSearch | Lancer MicroCRM avec `docker compose --env-file ../.env up -d` (pas sans `--env-file`) |
| Sync DORA manuelle | `docker exec dora-sync /app/sync-dora-from-github.sh -d 90` |

## Licence / contexte

Projet pédagogique OpenClassroom — module P7 DevOps / intégration continue.
