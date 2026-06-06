# Métriques DORA — laurentcoufinal/projet9

Période : **28 jours** — à régénérer après chaque sprint.

| Métrique DORA | Valeur observée | Commentaire |
|---------------|-----------------|-------------|
| **Lead Time for Changes** | *à générer* | `./scripts/export-dora-metrics.sh -o P7-FSJA/reports/dora-latest.md` |
| **Deployment Frequency** | *à générer* | Workflows CD réussis |
| **MTTR** | *à générer* | Délai échec CI → succès sur `main` |
| **Change Failure Rate** | *à générer* | Échecs CD / total CD |

> Exécuter avec `GITHUB_TOKEN` ou `gh auth login` : `./scripts/export-dora-metrics.sh -o P7-FSJA/reports/dora-latest.md`  
> Dashboard temps réel : OpenSearch Dashboards → **MicroCRM DORA** (sync nocturne via conteneur `dora-sync`)
