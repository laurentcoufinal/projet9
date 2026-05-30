# Documentation technique — Scénario Orion MicroCRM

| | |
|---|---|
| **Titre** | Documentation technique — Industrialisation CI/CD MicroCRM |
| **Option** | **Option B — Scénario Orion** (entreprise fictive Orion, application MicroCRM) |
| **Auteur** | LT |
| **Date** | 23/05/2026 (mise à jour) |
| **Dépôt** | https://github.com/laurentcoufinal/projet9 |
| **Application** | Orion MicroCRM (Spring Boot 3 + Angular 18) |

---

## 1. Introduction

### 1.1 Contexte du projet

Orion est une entreprise spécialisée dans les solutions technologiques. Elle développe **MicroCRM**, une application CRM simplifiée destinée aux équipes technique et commerciale. Jusqu’à présent, les déploiements étaient manuels, ce qui entraînait retards, erreurs humaines et difficulté à maintenir la qualité.

Ce projet vise à **industrialiser la chaîne de livraison** : automatisation des builds, des tests, de l’analyse qualité/sécurité et du déploiement conteneurisé.

### 1.2 Objectifs de l’industrialisation

- Réduire le délai entre un commit et une version déployable testable.
- Garantir la **non-régression** via des tests automatisés à chaque modification.
- Intégrer **SonarCloud** pour la qualité et les vulnérabilités.
- Standardiser le déploiement avec **Docker** et **Docker Compose**.
- Documenter les procédures (sécurité, sauvegarde, mises à jour).
- Mettre en place une **journalisation centralisée** (OpenSearch / SIEM) pour défauts, accès API et événements CI.

### 1.3 Technologies principales

| Couche | Technologie |
|--------|-------------|
| Backend | Java 17, Spring Boot 3.2, Spring Data REST, Gradle 8.7, HSQLDB |
| Frontend | Angular 18.2, TypeScript, Karma/Jasmine |
| Conteneurisation | Docker multi-stage, Caddy, Alpine Linux |
| CI/CD | GitHub Actions, GHCR |
| Qualité / sécurité | SonarCloud, JaCoCo, Dependabot |
| Observabilité | OpenSearch 2.x, OpenSearch Dashboards, Fluent Bit ; index `microcrm-defects`, `microcrm-security-events`, `microcrm-server-state` |

**Équivalence stack ELK (demande Maria) :** la stack « ELK » est mise en œuvre en **open source** sans cloud obligatoire :

| Composant ELK | Rôle | Implémentation MicroCRM |
|---------------|------|-------------------------|
| **E**lasticsearch | Stockage et recherche | **OpenSearch** (cluster Docker) |
| **L**ogstash | Collecte / transformation | **Fluent Bit** (logs conteneurs + parser JSON) |
| **K**ibana | Visualisation | **OpenSearch Dashboards** (dashboard **MicroCRM SOC**) |

**Documents associés :** [definition_test.md](definition_test.md), [domaine.md](domaine.md), [information_logge.md](../information_logge.md), [observability/opensearch/README.md](../observability/opensearch/README.md).

### 1.4 Pipeline CI/CD — vue d’ensemble

**Schéma (draw.io) :** [`diagrams/pipeline-cicd-overview.drawio`](diagrams/pipeline-cicd-overview.drawio) — ouvrir avec [diagrams.net](https://app.diagrams.net) ou l’extension Draw.io de VS Code. Pour le PDF, exporter en PNG depuis draw.io (*Fichier → Exporter → PNG*).

| Zone | Contenu |
|------|---------|
| **CI** (push / PR) | `backend` et `frontend` en parallèle → `sonarcloud` → `docker` ; indexation OpenSearch optionnelle après Sonar/Docker |
| **CD** (`main`) | Publication des images sur GHCR après CI réussi |
| **Nightly** (02h UTC) | Tests complets → smoke Docker Compose |

Les jobs `sonarcloud` et `docker` peuvent indexer un événement de sécurité dans OpenSearch (`index-ci-event.sh`) si `OPENSEARCH_URL` et `OPENSEARCH_PASSWORD` sont configurés dans GitHub (étape non bloquante).

**Workflows GitHub :**

- `ci.yml` — build, tests, analyse SonarCloud, construction des images, indexation CI optionnelle vers OpenSearch.
- `cd.yml` — publication des images sur GitHub Container Registry après CI réussi sur `main`.
- `nightly.yml` — exécution planifiée quotidienne (tests + Sonar + smoke test Compose).

---

## 2. Étapes de mise en œuvre du pipeline CI/CD

### 2.1 Structure du pipeline

#### Étapes principales

| Étape | Job GitHub Actions | Description |
|-------|-------------------|-------------|
| Build backend | `backend` | `./gradlew build test jacocoTestReport` |
| Build frontend | `frontend` | `npm ci`, `ng build`, `npm run test:ci` |
| Analyse qualité | `sonarcloud` | Scan SonarCloud (Java + TypeScript) |
| Conteneurisation | `docker` | `docker compose build` |
| Déploiement | `cd` (séparé) | Push images vers `ghcr.io` |

#### Ordre d’exécution

1. `backend` et `frontend` en **parallèle**.
2. `sonarcloud` après succès des deux (nécessite binaires Java et rapport LCOV front).
3. `docker` après succès des jobs de build (indépendant de Sonar pour ne pas bloquer en phase de mise en route).
4. `cd` déclenché par la complétion réussie de CI sur `main`, ou manuellement (`workflow_dispatch`).

#### Justification des actions GitHub

| Action | Rôle |
|--------|------|
| `actions/checkout@v4` | Récupération du code source |
| `actions/setup-java@v4` | JDK 17 Temurin + cache Gradle |
| `actions/setup-node@v4` | Node 20 + cache npm |
| `browser-actions/setup-chrome@v1` | Chrome headless pour Karma en CI |
| `SonarSource/sonarcloud-github-action@v2` | Analyse statique centralisée |
| `docker/setup-buildx-action@v3` | Build Docker optimisé |
| `docker/login-action@v3` + `build-push-action@v6` | Publication GHCR |

### 2.2 Scripts d’automatisation

| Script / commande | Rôle |
|-------------------|------|
| `back/gradlew build test jacocoTestReport` | Compile, teste et produit la couverture Java |
| `front/npm run test:ci` | Tests unitaires headless + couverture LCOV |
| [`scripts/verify-docker.sh`](scripts/verify-docker.sh) | Validation locale : build Compose, démarrage, curl API/UI |
| [`../observability/opensearch/setup-siem.sh`](../observability/opensearch/setup-siem.sh) | Initialisation index, modèles et politiques SIEM OpenSearch |
| [`../observability/opensearch/index-ci-event.sh`](../observability/opensearch/index-ci-event.sh) | Indexation d’événements CI (`sonar.quality_gate`, `docker.build`) |
| [`../observability/opensearch/setup-slack-destination.sh`](../observability/opensearch/setup-slack-destination.sh) | Destination Alerting + actions Slack sur moniteurs P0 |
| [`../scripts/notify-slack.sh`](../scripts/notify-slack.sh) | Notification Slack (CI / nightly en échec) |
| [`../scripts/export-dora-metrics.sh`](../scripts/export-dora-metrics.sh) | Export métriques DORA depuis GitHub Actions |
| [`../observability/scripts/health-status.sh`](../observability/scripts/health-status.sh) | Rapport santé cluster + API + CI |
| `docker compose up -d` | Orchestration back + front en local |

**Exécution locale du script de vérification :**

```bash
cd P7-FSJA
./scripts/verify-docker.sh
```

**Initialisation SIEM (stack OpenSearch démarrée) :**

```bash
# Depuis la racine du dépôt, après docker compose -f docker-compose-opensearch.yml up -d
./observability/opensearch/setup-siem.sh
```

### 2.3 Observabilité CI (optionnelle)

Après les jobs `sonarcloud` et `docker` de [`ci.yml`](../.github/workflows/ci.yml), le workflow exécute `index-ci-event.sh` avec `continue-on-error: true` : l’échec d’OpenSearch n’interrompt pas la CI.

| Variable GitHub | Type | Usage |
|-----------------|------|-------|
| `OPENSEARCH_URL` | Variable (`vars`) | URL HTTPS du cluster (ex. tunnel ou instance dédiée) |
| `OPENSEARCH_PASSWORD` | Secret | Mot de passe utilisateur `admin` OpenSearch |

Les valeurs ne doivent **jamais** être commitées dans le dépôt.

### 2.4 Reproductibilité

**Relancer le pipeline :**

- Push ou PR sur `main` → déclenche `ci.yml`.
- Onglet Actions → workflow **Nightly** → *Run workflow*.
- Onglet Actions → workflow **CD** → *Run workflow* (publication manuelle).

**Gestion des secrets (jamais affichés dans les logs) :**

| Secret / variable | Usage |
|-------------------|-------|
| `SONAR_TOKEN` | Authentification SonarCloud (à créer sur sonarcloud.io) |
| `GITHUB_TOKEN` | Fourni automatiquement ; utilisé pour Sonar et push GHCR |
| `SLACK_WEBHOOK_URL` | Secret — Incoming Webhook Slack (alertes CI + OpenSearch) |
| `OPENSEARCH_URL` | Variable — URL du cluster pour indexation événements CI |
| `OPENSEARCH_PASSWORD` | Secret — authentification OpenSearch (admin) |

**Configuration SonarCloud :** fichier [`sonar-project.properties`](sonar-project.properties) — clés `laurentcoufinal_projet9` / organisation `laurentcoufinal` (à aligner avec le projet créé sur SonarCloud).

---

## 3. Plan de conteneurisation et de déploiement

### 3.1 Dockerfiles

Le [`Dockerfile`](Dockerfile) utilise un **build multi-stage** :

| Stage | Image de base | Résultat |
|-------|---------------|----------|
| `front-build` | `node` | Build Angular optimisé |
| `back-build` | `gradle:jdk17` | JAR Spring Boot |
| `front` | `alpine:3.19` + Caddy | Assets statiques, ports 80/443 |
| `back` | `alpine:3.19` + JRE 21 | API sur port **8080** |
| `standalone` | Alpine + Supervisor | Front + back dans un seul conteneur (profil optionnel) |

**Choix techniques :**

- Images Alpine légères pour l’exécution.
- `npm ci` et `./gradlew build` dans des stages dédiés pour maximiser le cache Docker.
- `curl` / `wget` ajoutés pour les healthchecks.
- Correction du port exposé backend : `8080` (et non 4200).

### 3.2 docker-compose.yml

**Services :**

| Service | Image cible | Ports hôte |
|---------|-------------|------------|
| `back` | `target: back` | 8080 |
| `front` | `target: front` | 80, 443 |
| `standalone` | profil `standalone` | 8080, 80, 443 |

**Healthchecks :**

- Backend : `curl -f http://localhost:8080/persons`
- Frontend : `wget` sur `http://localhost:80/`
- Le front démarre uniquement si le back est `healthy` (`depends_on`).

**Lancement local :**

```bash
cd P7-FSJA
docker compose build
docker compose up -d
# API : http://localhost:8080/persons
# UI  : https://localhost (redirection HTTP → HTTPS par Caddy)
docker compose down
```

**Profil tout-en-un :**

```bash
docker compose --profile standalone up -d
```

**Note réseau :** le frontend appelle l’API via `http://localhost:8080` ([`config.ts`](front/src/app/config.ts)). Avec les ports publiés sur l’hôte, le navigateur accède correctement à l’API.

**Journalisation conteneurs :** par défaut, les services MicroCRM utilisent le driver **`json-file`** (arrêt propre via `docker compose down`). Pour envoyer les logs vers Fluent Bit, utiliser le profil optionnel :

```bash
docker compose -f docker-compose.yml -f docker-compose.fluent-logs.yml up -d
```

### 3.3 Déploiement (GHCR)

Images publiées par le workflow CD :

- `ghcr.io/laurentcoufinal/projet9/orion-microcrm-back:latest`
- `ghcr.io/laurentcoufinal/projet9/orion-microcrm-front:latest`

Sur une machine cible :

```bash
docker login ghcr.io -u <utilisateur>
docker pull ghcr.io/laurentcoufinal/projet9/orion-microcrm-back:latest
docker pull ghcr.io/laurentcoufinal/projet9/orion-microcrm-front:latest
cd P7-FSJA && docker compose up -d
```

### 3.4 Stack observabilité (optionnelle)

Fichier racine [`docker-compose-opensearch.yml`](../docker-compose-opensearch.yml) — indépendant de MicroCRM :

| Service | Rôle | Port hôte |
|---------|------|-----------|
| `opensearch-node1` / `node2` | Cluster OpenSearch | 9200 |
| `opensearch-dashboards` | UI (Security Analytics, Alerting) | 5601 |
| `fluent-bit` | Collecte logs conteneurs + parsing JSON / lignes `SECURITY` | 24224 |

**Lancement :**

```bash
# Racine du dépôt — fichier .env requis (OPENSEARCH_INITIAL_ADMIN_PASSWORD, etc.)
docker compose -f docker-compose-opensearch.yml up -d
cd P7-FSJA && docker compose up -d
```

Référence détaillée des index et champs : [information_logge.md](../information_logge.md). Configuration Fluent Bit : [`observability/fluent-bit/`](../observability/fluent-bit/).

Le backend indexe les défauts et les accès sensibles lorsque `opensearch.enabled=true` (désactivé en CI : `OPENSEARCH_ENABLED=false`).

---

## 4. Plan de testing périodique

### 4.1 Types de tests automatisés

| Type | Outil | Périmètre |
|------|-------|-----------|
| Spécification BDD (Gherkin) | [definition_test.md](definition_test.md) | 90 scénarios — `@existant` / `@a_implementer`, traçabilité JUnit/Karma |
| Unitaires domaine backend | JUnit 5 | `PersonTest`, `OrganizationTest` |
| Intégration persistance | `@DataJpaTest` | `PersonRepositoryIntegrationTest` |
| Infrastructure web / exceptions | JUnit 5 + Mockito | `RequestIdFilterTest`, `GlobalExceptionHandlerTest` |
| Observabilité OpenSearch | JUnit 5 + Mockito | `OpenSearch*Test`, `SecurityAccessLogFilterTest` |
| Démarrage application | `@SpringBootTest` | `MicroCRMApplicationTests`, `OpenSearchConfigTest` |
| Unitaires frontend | Karma, Jasmine, Chrome headless | 8 fichiers `*.spec.ts` (services, composants, intercepteur) |
| Couverture | JaCoCo (Java), karma-coverage LCOV (TS) | Alimente SonarCloud |
| Qualité / sécurité statique | SonarCloud | Code smells, vulnérabilités, hotspots |
| Smoke infrastructure | `curl` sur stack Docker Compose | Job `docker-smoke` (nightly) |
| API REST / E2E (cible) | REST Assured, Playwright | 17 + 7 scénarios `@a_implementer` — voir §4.1 de [definition_test.md](definition_test.md) |

**Inventaire chiffré (mesures locales, mai 2026) :**

| Métrique | Backend | Frontend |
|----------|---------|----------|
| Nombre de tests | **34** (10 classes `*Test.java`) | **34** (8 specs) |
| Couverture lignes | **~94 %** JaCoCo (246/262) | **~96 %** Karma (128/134) |
| Objectif SonarCloud | ≥ **80 %** | ≥ **80 %** |

**Tests observabilité et web (§4.1 de definition_test.md) :**

| Classe de test | Scénarios couverts |
|----------------|-------------------|
| `RequestIdFilterTest` | Conservation / génération `X-Request-Id` |
| `GlobalExceptionHandlerTest` | 400, 409, 500, troncature stack, indexation défauts |
| `OpenSearchPropertiesTest` | Contrat configuration OpenSearch |
| `OpenSearchConfigTest` | Bean `OpenSearchClient` si `opensearch.enabled=true` |
| `OpenSearchDefectLoggerTest` | Indexation défauts, résilience |
| `OpenSearchSecurityEventLoggerTest` | Indexation événements sécurité |
| `SecurityAccessLogFilterTest` | Journal accès API, IP, User-Agent, chemins Actuator |

### 4.2 Fréquence d’exécution

| Moment | Tests exécutés |
|--------|----------------|
| **Push / PR** sur `main` | Build, tests back/front, SonarCloud, build Docker |
| **Nightly** (cron `0 2 * * *` UTC) | Tests complets, Sonar, smoke Compose |
| **Publication images** | Déclenchement CD après CI vert sur `main`, ou manuel (`workflow_dispatch`) — pas de workflow dédié aux tags `v*` |
| **Dependabot** (hebdomadaire) | PR de mise à jour dépendances (Gradle, npm, Actions, Docker) |

### 4.3 Objectifs et critères

| Objectif | Critère de réussite | Alerte |
|----------|---------------------|--------|
| Qualité code | Quality Gate SonarCloud **OK** (couverture ≥ 80 % visée) | Échec job `sonarcloud` |
| Non-régression | 100 % tests unitaires/intégration verts (34 + 34) | Échec `backend` ou `frontend` → **Slack** |
| Déploiement sain | Healthchecks Compose + curl API | Échec `docker-smoke` → **Slack** |
| Performance pipeline | Build CI < 15 min (cible) | Slack si échec workflow |

### 4.4 Synthèse couverture pour Maria

| Couche | Tests | Couverture lignes | Scénarios BDD `@existant` |
|--------|-------|-------------------|---------------------------|
| Backend | 34 (10 classes) | ~94 % JaCoCo | Domaine + web + OpenSearch |
| Frontend | 34 (8 specs) | ~96 % Karma | Services + composants |
| **Total automatisé** | **68** | **≥ 80 %** (objectif Sonar) | 54 / 90 dans [definition_test.md](definition_test.md) |
| Cible itération suivante | API REST + E2E | — | 24 scénarios `@a_implementer` |

---

## 5. Plan de sécurité

### 5.1 Résultats SonarCloud

Analyse basée sur les rapports de couverture locaux et les corrections appliquées (mai 2026). Dashboard : https://sonarcloud.io/project/overview?id=laurentcoufinal_projet9

| Indicateur | Avant remédiation | Après remédiation (local, mai 2026) | Objectif Quality Gate |
|------------|-------------------|-------------------------------------|------------------------|
| Couverture backend (lignes) | ~64 % | **~94 %** (JaCoCo, 34 tests) | ≥ 80 % (projet) ; ≥ 50 % (gate par défaut) |
| Couverture frontend (lignes) | ~31 % | **~96 %** (34 tests Karma) | ≥ 80 % (projet) ; ≥ 50 % (gate par défaut) |
| CORS wildcard `*` | Présent | **Corrigé** — origines explicites via `app.cors.allowed-origins` | Hotspot revu |
| NPE `@PreRemove` | Risque | **Corrigé** — garde `organizations != null` | Bug fermé |
| Dépendance Gradle dupliquée | Oui | **Corrigée** | Code smell fermé |
| Validation entrées REST | Absente | **Ajoutée** — `@NotBlank`, `@Email` sur `Person` / `Organization` | Fiabilité améliorée |
| `CascadeType.ALL` | Présent | **Remplacé** par `PERSIST`, `MERGE` | Risque données réduit |
| Vulnérabilités npm (High) | 28 (Angular 17) | **28** signalées par `npm audit` après **Angular 18.2.14** (dernier patch 18.2.x ; correctifs complets proposés en 19.x uniquement) | Suivi Dependabot |
| Version Angular | 17.3.x | **18.2.14** (LTS) | Patches XSS/XSRF de la branche 18 |

**Corrections code principales :**

- [`SpringDataRestCustomization.java`](back/src/main/java/com/openclassroom/devops/orion/microcrm/SpringDataRestCustomization.java) : CORS configurable.
- [`Person.java`](back/src/main/java/com/openclassroom/devops/orion/microcrm/Person.java) : `removeFromOrganization()`, validation Jakarta.
- Tests : `PersonTest`, `OrganizationTest`, `GlobalExceptionHandlerTest`, `SecurityAccessLogFilterTest`, specs Angular avec `HttpTestingController`.
- **SIEM (A09)** : `GlobalExceptionHandler` → index `microcrm-defects` ; `SecurityAccessLogFilter` → index `microcrm-security-events` ; corrélation via `X-Request-Id` ([`RequestIdFilter`](back/src/main/java/com/openclassroom/devops/orion/microcrm/web/RequestIdFilter.java)).
- Types HAL typés dans [`models.ts`](front/src/app/models.ts) ; `API_BASE_URL` via [`environment.ts`](front/src/environments/environment.ts).
- Migration **Angular 18.2.14** : `ng update @angular/core@18 @angular/cli@18` ; providers HTTP (`provideHttpClient`) dans les specs.
- Rapports npm : [`front/audit-avant.txt`](front/audit-avant.txt), [`front/audit-apres.txt`](front/audit-apres.txt).

Le pipeline transmet les rapports aux chemins définis dans [`sonar-project.properties`](sonar-project.properties) :

- `back/build/reports/jacoco/test/jacocoTestReport.xml`
- `front/coverage/lcov.info`

Voir annexe C et [`docs/annexes/README.md`](docs/annexes/README.md) pour les captures à déposer après scan.

#### Règles Sonar prioritaires (synthèse Maria)

| Règle / thème | Statut | Action |
|---------------|--------|--------|
| Couverture lignes ≥ 80 % | **Atteint** localement (~94 % / ~96 %) | Maintenir sur chaque PR |
| CORS wildcard | **Corrigé** | Origines explicites `app.cors.allowed-origins` |
| Validation `@NotBlank` / `@Email` | **Corrigé** | Person, Organization |
| NPE `@PreRemove` | **Corrigé** | Garde `organizations != null` |
| `CascadeType.ALL` | **Corrigé** | `PERSIST`, `MERGE` uniquement |
| Vulnérabilités npm (High) | **Ouvert** | Suivi Dependabot ; migration Angular 19+ si besoin |
| Quality Gate bloquante CI | **À activer** | Configuration projet SonarCloud |
| Authentification API | **Hors périmètre démo** | Spring Security avant prod |

### 5.2 Analyse des risques (OWASP Top 10 — contexte MicroCRM)

| Risque OWASP | Évaluation | Mesure en place |
|--------------|------------|-----------------|
| A01 — Contrôle d’accès | **Élevé** (app sans authentification) | Accepté pour démo interne ; à traiter avant exposition Internet |
| A02 — Défaillances cryptographiques | Faible | HTTPS via Caddy en conteneur front |
| A03 — Injection | Faible | Spring Data JPA, pas de SQL natif concaténé |
| A04 — Conception non sécurisée | Moyen | Revue Sonar + Dependabot |
| A05 — Mauvaise configuration | Moyen | Secrets GitHub, pas de credentials dans le repo |
| A06 — Composants vulnérables | **Moyen/Élevé** | npm audit signale des vulnérabilités ; Dependabot hebdomadaire |
| A07 — Identification / auth | N/A (hors périmètre actuel) | — |
| A08 — Intégrité logicielle | Faible | CI sur GitHub, images signées par registre GHCR |
| A09 — Journalisation | **Renforcé** | Index `microcrm-defects`, `microcrm-security-events`, `microcrm-server-state` ; filtres back + Fluent Bit ; dashboards Security Analytics / Alerting ; audit OpenSearch (`security-auditlog-*`) — voir [information_logge.md](../information_logge.md) |
| A10 — SSRF | Faible | Pas d’appels HTTP sortants dynamiques côté API |

**Risques pipeline :**

- Fuite de `SONAR_TOKEN` → stockage uniquement dans GitHub Secrets.
- Actions compromises → versions épinglées (`@v4`, `@v2`), Dependabot sur `github-actions`.
- Images obsolètes → surveillance `alpine:3.19`, mises à jour planifiées.

### 5.3 Plan d’action / remédiation

| Priorité | Action | Statut |
|----------|--------|--------|
| **Immédiat** | Configurer `SONAR_TOKEN` ; corriger CORS, NPE, smells Gradle | Fait (code) |
| **Immédiat** | Renforcer tests back/front pour couverture Quality Gate (≥ 80 %) | **Fait** (34 tests Java, 34 Karma, ~94 % / ~96 %) |
| **Immédiat** | Tests observabilité (handlers, filtres, loggers OpenSearch) | **Fait** — voir [definition_test.md](definition_test.md) §4.1 |
| **Court terme** | Migration Angular 18.2.14 + `npm audit fix` | Fait ; audit npm résiduel documenté |
| **Court terme** | Alertes **Slack** (OpenSearch P0 + échec CI/nightly) | **Fait** — `setup-slack-destination.sh`, `notify-slack.sh`, workflows |
| **Court terme** | Activer Quality Gate bloquante en CI après premier scan vert | **À faire** sur SonarCloud |
| **Moyen terme** | Spring Security si exposition réseau élargie | Planifié |
| **Long terme** | Trivy, WAF, base persistante chiffrée | Planifié |

---

## 6. Monitoring, métriques et KPI

### 6.1 Métriques DORA

Calculées à partir de l’historique GitHub Actions (onglet *Insights* → *Actions*) :

| Métrique | Définition | Source |
|----------|------------|--------|
| **Lead Time for Changes** | Temps entre commit et déploiement image disponible | `ci.yml` + `cd.yml` timestamps |
| **Deployment Frequency** | Nombre de déploiements réussis / semaine | Runs `CD` sur `main` |
| **MTTR** | Temps moyen de rétablissement après échec CI | Durée entre échec et premier run vert |
| **Change Failure Rate** | % de déploiements entraînant un rollback ou hotfix | Échecs `cd` / total déploiements |

Rapport généré par [`scripts/export-dora-metrics.sh`](../scripts/export-dora-metrics.sh) — dernier export : [reports/dora-latest.md](reports/dora-latest.md).

```bash
gh auth login
./scripts/export-dora-metrics.sh -o P7-FSJA/reports/dora-latest.md
```

| Métrique | Définition | Source |
|----------|------------|--------|
| **Lead Time for Changes** | Commit → image GHCR disponible | `ci.yml` + `cd.yml` |
| **Deployment Frequency** | Déploiements CD réussis / semaine | Workflow `CD` |
| **MTTR** | Délai échec CI → succès sur `main` | Historique Actions |
| **Change Failure Rate** | % CD en échec | Runs `CD` |

### 6.2 KPI proposés à Maria

#### Application (logs, volumétrie, pics, erreurs)

| KPI | Seuil / cible | Source OpenSearch | Alerte Slack |
|-----|---------------|-------------------|--------------|
| Erreurs 5xx | < 10 / 5 min | `microcrm-defects` | `[P0] spike 5xx` |
| Erreurs 4xx | < 50 / 5 min | `microcrm-defects` | `[P1] spike 4xx` |
| Santé conteneurs | 0 `down` / 2 min | `microcrm-server-state` | `[P0] service unhealthy` |
| Volume requêtes API | Histogramme / heure | `microcrm-security-events` | Dashboard SOC |
| DELETE massifs | < 20 / 10 min | `microcrm-security-events` | `[P1] mass DELETE` |
| Corrélation incident | `requestId` commun | Tous index | Discover |

#### Pipeline et qualité

| KPI | Cible indicative | Source |
|-----|------------------|--------|
| Couverture backend | ≥ 80 % (obs. ~94 %) | JaCoCo / SonarCloud |
| Couverture frontend | ≥ 80 % (obs. ~96 %) | Karma LCOV / SonarCloud |
| Durée job `backend` | < 3 min | GitHub Actions |
| Durée job `frontend` | < 5 min | GitHub Actions |
| Durée smoke nightly | < 5 min | `nightly.yml` |
| Taux d’échec CI (30 j) | < 10 % | `export-dora-metrics.sh` |
| Quality Gate Sonar | OK | SonarCloud |

### 6.3 Synthèse monitoring et maturité pipeline

- **Points forts :** stack ELK équivalente opérationnelle en local ; dashboard **MicroCRM SOC** ; alertes **Slack** (moniteurs P0 + échec CI/nightly) ; export DORA scriptable ; couverture tests ≥ 80 %.
- **Points à améliorer :** Quality Gate Sonar bloquante ; captures SonarCloud en annexe ; smoke OpenSearch dans CI nightly (optionnel).
- **Dashboards :** OpenSearch Dashboards (:5601), SonarCloud, GitHub Actions, GHCR.
- **Démo Maria :** [observability/opensearch/DEMO-MARIA.md](../observability/opensearch/DEMO-MARIA.md).
- **Références :** [information_logge.md](../information_logge.md), [observability/opensearch/README.md](../observability/opensearch/README.md).

#### Interprétation maturité (synthèse DORA)

| Niveau | Indicateur | Recommandation |
|--------|------------|----------------|
| Lead Time | Réduire durée CI (caches, parallélisme) | Déjà en place ; viser < 15 min total |
| Deployment Frequency | Augmenter fréquence merges sur `main` | CD automatique après CI vert |
| MTTR | Alertes Slack + runbook | `health-status.sh`, canal `#orion-microcrm-alerts` |
| Change Failure Rate | Quality Gate + tests 34+34 | Activer gate bloquante SonarCloud |

---

## 7. Plan de sauvegarde des données

### 7.1 Ce qui doit être sauvegardé

| Élément | Criticité | Remarque |
|---------|-----------|----------|
| Code source (Git) | Haute | Source de vérité sur GitHub |
| Workflows / config CI | Haute | `.github/workflows/`, `docker-compose.yml`, `sonar-project.properties` |
| Config observabilité | Moyenne | `observability/`, `docker-compose-opensearch.yml`, `.env` (hors repo) |
| Artefacts build | Moyenne | JAR, images Docker sur GHCR |
| Données CRM | **Basse** (démo) | HSQLDB **en mémoire** — perdues au redémarrage |
| Indices OpenSearch | Moyenne (si SIEM actif) | Export snapshot ou reindex — voir doc OpenSearch |
| Rapports Sonar | Moyenne | Export PDF / captures depuis SonarCloud |

### 7.2 Procédure de sauvegarde

| Élément | Fréquence | Commande / outil |
|---------|-----------|------------------|
| Dépôt Git | Continu (push) | `git push origin main` |
| Images Docker | À chaque CD réussi | Automatique GHCR ; export local : `docker save -o microcrm-back.tar orion-microcrm-back:latest` |
| Configuration | Hebdomadaire | Tag Git `backup-YYYY-MM-DD` ou branche archive |
| Config observabilité | À chaque changement SIEM | Commit `observability/` + copie `.env` sécurisée |
| Rapport Sonar | Mensuel | Export depuis l’interface SonarCloud |

### 7.3 Procédure de restauration

**Scénario : déploiement défectueux**

1. Identifier le dernier commit / image stable (`git log`, tag GHCR `sha-xxx`).
2. `git checkout <tag-stable>` ou `docker pull ghcr.io/.../orion-microcrm-back:<sha>`.
3. `docker compose down && docker compose up -d`.
4. Vérifier : `curl http://localhost:8080/persons`.

**Limitations :** aucune restauration de données métier (base volatile). Les fixtures Spring rechargent les données de démo au démarrage. Les indices OpenSearch ne sont pas sauvegardés automatiquement par le pipeline.

---

## 8. Plan de mise à jour

### 8.1 Application

| Composant | Outil | Fréquence |
|-----------|-------|-----------|
| Dépendances Maven | Dependabot (`/P7-FSJA/back`) | Hebdomadaire |
| Dépendances npm | Dependabot (`/P7-FSJA/front`) | Hebdomadaire |
| Spring Boot / Angular | PR manuelle après revue changelog | Trimestrielle |
| Images Docker de base | Dependabot docker + revue Dockerfile | Mensuelle |

### 8.2 Pipeline CI/CD

- Mise à jour des actions GitHub via PR Dependabot.
- Revue semestrielle des workflows (permissions, caches, durées).
- Rotation du token SonarCloud annuelle.

### 8.3 Bonnes pratiques

- Toujours passer par une PR pour valider l’impact des mises à jour.
- Ne jamais merger une PR Dependabot sans CI verte.
- Tester localement `verify-docker.sh` avant merge des changements Docker majeurs.

---

## 9. Conclusion

### 9.1 Améliorations apportées

- Pipeline CI/CD complet sur GitHub Actions (build, tests, SonarCloud, Docker).
- Orchestration **Docker Compose** avec healthchecks et script de validation.
- Publication automatisée des images sur **GHCR**.
- Tests **nightly** (smoke Compose) et alertes Dependabot.
- **SIEM OpenSearch** : défauts API, journal d’accès, logs conteneurs, événements CI.
- Couverture de tests **≥ 80 %** (backend ~94 %, frontend ~96 %) — objectif SonarCloud atteint localement.
- Documentation opérationnelle : [definition_test.md](definition_test.md), [information_logge.md](../information_logge.md), plans sécurité / sauvegarde / testing.

### 9.2 Gains observés / attendus

| Dimension | Gain |
|-----------|------|
| Fiabilité | 34 + 34 tests systématiques avant merge ; smoke nightly |
| Rapidité | Builds parallèles, cache, images prêtes à déployer |
| Qualité | SonarCloud + couverture JaCoCo/LCOV |
| Sécurité | Analyse statique, SIEM, corrélation `X-Request-Id`, suivi OWASP |
| Observabilité | Dashboards OpenSearch, indexation défauts et accès sensibles |

### 9.3 Recommandations

1. Activer la Quality Gate bloquante sur SonarCloud après validation du prochain scan CI.
2. Implémenter les scénarios `@a_implementer` : tests API REST (17) et E2E (7) — voir [definition_test.md](definition_test.md).
3. Traiter les vulnérabilités npm signalées par `npm audit` (Dependabot / migration Angular 19+).
4. Ajouter Spring Security avant toute exposition Internet.
5. Compléter les tests API REST et E2E (`@a_implementer`).

---

## 10. Écarts projet / template (manques identifiés)

Éléments prévus par le template ou le CDC mais **absents ou incomplets** dans le dépôt :

| Chapitre | Manque | Gravité | Piste de remédiation |
|----------|--------|---------|----------------------|
| §4 Tests | 17 scénarios API REST `@a_implementer` | Haute | REST Assured / `TestRestTemplate` dans `back/src/test/.../api/` |
| §4 Tests | 7 scénarios E2E Playwright/Cypress | Haute | `P7-FSJA/e2e/` |
| §4 Tests | 6 scénarios UI dashboard `@a_implementer` | Moyenne | Enrichir `main-dashboard.component.spec.ts` |
| §4 Tests | Intégration OpenSearch réelle (hors mocks) | Moyenne | Testcontainers OpenSearch |
| §4 Tests | Workflow release sur tags `v*` | Faible | Job `on: push: tags` |
| §5 Sécurité | Authentification / Spring Security | Haute (prod) | Accepté pour démo interne |
| §5 Sécurité | Scan images Trivy | Moyenne | Job CI dédié |
| §5 Sécurité | Quality Gate Sonar bloquante confirmée | Moyenne | Configuration SonarCloud |
| §5 Sécurité | Vulnérabilités npm résiduelles | Moyenne | Dependabot, Angular 19+ |
| §6 Monitoring | Valeurs DORA à jour après chaque sprint | Faible | `./scripts/export-dora-metrics.sh` |
| §6 Monitoring | Configurer `SLACK_WEBHOOK_URL` en prod | Faible | Secret GitHub + `setup-slack-destination.sh` |
| §3 Déploiement | Base persistante (HSQLDB mémoire) | Faible (démo) | PostgreSQL + volume Docker |
| §6 Monitoring | Smoke OpenSearch dans CI | Faible | Job nightly optionnel |
| Annexes | Captures SonarCloud réelles | Faible | Post-scan CI sur `main` |

**Déjà conforme au template :** CI/CD GitHub Actions, SonarCloud, JaCoCo/LCOV, Docker multi-stage, Compose + healthchecks, Dependabot, nightly + smoke, SIEM OpenSearch, documentation README et plans sécurité/sauvegarde.

---

## Annexes

### A. Extrait workflow CI (sonarcloud)

```yaml
- name: SonarCloud Scan
  uses: SonarSource/sonarcloud-github-action@v2
  with:
    projectBaseDir: P7-FSJA
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

### B. Commandes utiles

```bash
# Tests backend
cd P7-FSJA/back && ./gradlew test jacocoTestReport

# Tests frontend (CI — Chrome requis)
cd P7-FSJA/front && npm run test:ci

# Stack MicroCRM
cd P7-FSJA && docker compose up -d

# Stack observabilité (racine dépôt)
docker compose -f docker-compose-opensearch.yml up -d
./observability/opensearch/setup-siem.sh

# Vérification automatisée
./P7-FSJA/scripts/verify-docker.sh
```

### C. Captures SonarCloud

Placer les fichiers dans [`docs/annexes/`](docs/annexes/) :

| Fichier | Contenu |
|---------|---------|
| `sonar-overview.png` | Quality Gate + vue projet |
| `sonar-coverage.png` | Couverture Java / TypeScript |
| `sonar-security.png` | Vulnérabilités et hotspots |

Dashboard : https://sonarcloud.io/project/overview?id=laurentcoufinal_projet9

### D. Export PDF

```bash
# Exemple avec Pandoc (pdflatex ou xelatex requis pour le PDF)
pandoc P7-FSJA/documentation-technique.md -o documentation-technique.pdf --toc
# Alternative sans LaTeX : export HTML puis impression navigateur
pandoc P7-FSJA/documentation-technique.md -o documentation-technique.html --toc --standalone
```

Volume estimé : ~4 000 mots / 619 lignes — conforme à la cible CDC (10–15 pages PDF).

### E. Observabilité — commandes SIEM

**Tutoriel dashboard :** [observability/opensearch/TUTORIEL-DASHBOARD.md](../observability/opensearch/TUTORIEL-DASHBOARD.md) — guide pas-à-pas pour le tableau de bord **MicroCRM SOC**.

Référence complète : [information_logge.md](../information_logge.md).

```bash
# Démarrer le cluster et Dashboards
docker compose -f docker-compose-opensearch.yml up -d

# Créer index et modèles SIEM
./observability/opensearch/setup-siem.sh

# Vérifier santé cluster
curl -ks -u admin:$OPENSEARCH_INITIAL_ADMIN_PASSWORD \
  https://localhost:9200/_cluster/health

# Dashboards : https://localhost:5601
```

Index principaux : `microcrm-defects`, `microcrm-security-events`, `microcrm-server-state`, `security-auditlog-*`.

### F. Alertes Slack

1. Créer Incoming Webhook Slack → canal `#orion-microcrm-alerts`.
2. GitHub : secret `SLACK_WEBHOOK_URL`.
3. OpenSearch : `export SLACK_WEBHOOK_URL=... && ./observability/opensearch/setup-slack-destination.sh`
4. Vérifier : provoquer un échec de workflow ou un spike 5xx de test.
