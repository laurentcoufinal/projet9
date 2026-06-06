# Projet 9 — Orion MicroCRM (CI/CD)

Industrialisation de l'application **MicroCRM** pour Orion : pipeline GitHub Actions, Docker Compose, SonarCloud, observabilité OpenSearch (SOC + DORA).

## Contenu du dépôt

| Fichier / dossier | Description |
|-------------------|-------------|
| [`P7-FSJA/`](P7-FSJA/) | Application Spring Boot + Angular et livrables DevOps |
| [`cdc.md`](cdc.md) | Cahier des charges |
| [`.github/workflows/`](.github/workflows/) | Pipelines CI, CD et nightly |
| [`docker-compose-opensearch.yml`](docker-compose-opensearch.yml) | Stack OpenSearch, Dashboards, Fluent Bit, dora-sync |

## Démarrage rapide

Procédure complète (MicroCRM + OpenSearch + dashboards) :

```bash
cp .env.example .env   # éditer OPENSEARCH_* + GITHUB_TOKEN (PAT Actions read)
docker compose -f docker-compose-opensearch.yml up -d --build
export OPENSEARCH_PASSWORD="$(grep OPENSEARCH_INITIAL_ADMIN_PASSWORD .env | cut -d= -f2-)"
./observability/opensearch/setup-siem.sh
cd P7-FSJA && docker compose --env-file ../.env up -d
```

| Service | URL |
|---------|-----|
| API | http://localhost:8080/persons |
| UI | https://localhost |
| Dashboards | http://localhost:5601 (MicroCRM SOC + MicroCRM DORA) |

Documentation détaillée : **[P7-FSJA/README.md](P7-FSJA/README.md)** — section [Démarrage complet (recommandé)](P7-FSJA/README.md#démarrage-complet-recommandé)

Documentation technique (PDF) : **[P7-FSJA/documentation-technique.md](P7-FSJA/documentation-technique.md)**
