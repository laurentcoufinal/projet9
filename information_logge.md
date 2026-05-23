# Journalisation MicroCRM → OpenSearch

## Index

| Index | Source | Contenu |
|-------|--------|---------|
| `microcrm-defects` | Back (`OpenSearchDefectLogger`) | Erreurs API 4xx/5xx + `requestId` |
| `microcrm-server-state` | Fluent Bit | Logs conteneurs, health TCP, métriques host |
| `microcrm-security-events` | Back + Fluent Bit + CI | Journal d'accès API, événements CI, backup logs `SECURITY` |
| `security-auditlog-*` | OpenSearch Security (audit) | Connexions admin, opérations cluster |

---

## microcrm-defects

**Quand :** uniquement en cas d'erreur gérée par `GlobalExceptionHandler` (pas chaque requête OK).

| Champ | Description |
|-------|-------------|
| `requestId` | UUID (`X-Request-Id` ou généré par le back) |
| `timestamp` | Date/heure de l'erreur |
| `level` | `"ERROR"` |
| `message` | Message d'erreur |
| `exceptionType` | Classe Java de l'exception |
| `stackTrace` | Stack trace (tronquée ~8 Ko) |
| `path` | URL (`/persons`, etc.) |
| `method` | GET, POST, PUT, DELETE… |
| `status` | 400, 409, 500… |

**Non indexé :** requêtes 200/201, données métier (PII), logs applicatifs normaux.

---

## microcrm-security-events (SIEM)

**Quand :** chaque requête API (sauf `/actuator/*`), événements CI, lignes `SECURITY` des logs conteneur.

| Champ | Description |
|-------|-------------|
| `requestId` | Corrélation avec défauts et logs |
| `timestamp` | Horodatage |
| `eventCategory` | `security` |
| `eventType` | `access`, `ci`, `audit` |
| `clientIp` | IP cliente (`X-Forwarded-For` ou remote) |
| `method` / `path` / `status` | Requête HTTP |
| `durationMs` | Durée traitement |
| `userAgent` | Tronqué 512 car. (pas de corps requête) |
| `outcome` | `success`, `client_error`, `server_error` |
| `sensitive` | `true` si DELETE ou mutation `/persons` / `/organizations` |
| `requestIdProvided` | `true` si le front a envoyé `X-Request-Id` |
| `ci_event` / `workflow` / `job` / `conclusion` | Événements pipeline CI |

---

## microcrm-server-state

| `event_type` | Source | Contenu |
|--------------|--------|---------|
| `log` | microcrm.* | stdout/stderr conteneurs |
| `health` | back / front / opensearch | Sonde TCP up/down |
| `metrics` | host | CPU, RAM, disque |

---

## Front

- Génère un UUID par requête → header `X-Request-Id`.
- Ne contacte pas OpenSearch directement.

---

## SIEM — quoi mesurer

| Famille | Mesure | Index |
|---------|--------|-------|
| Disponibilité | Health `down`, CPU/RAM/disque | `microcrm-server-state` |
| Abus API | Pic 4xx/5xx, DELETE massifs | `microcrm-defects`, `microcrm-security-events` |
| Traçabilité | `requestId` bout en bout | Tous |
| Plateforme | Audit admin OpenSearch | `security-auditlog-*` |
| Pipeline | Sonar, build Docker | `microcrm-security-events` (`eventType: ci`) |

### Alertes P0 (seuils)

| Alerte | Seuil |
|--------|-------|
| Spike 5xx | > 10 / 5 min |
| Spike 4xx | > 50 / 5 min |
| Service down | ≥ 1 health `down` / 2 min |
| DELETE massif | > 20 DELETE réussis / 10 min |

Provisionnement : `./observability/opensearch/setup-siem.sh`  
Dashboards : **MicroCRM SOC** (http://localhost:5601)

---

## Procédure incident

1. Récupérer le `requestId` (réponse API ou DevTools réseau).
2. **Discover** → index `microcrm-security-events` : `requestId:"<uuid>"`.
3. **Discover** → `microcrm-defects` : même `requestId` si erreur.
4. **Discover** → `microcrm-server-state` : logs conteneur autour du timestamp.
5. Vérifier alertes **Alerting** et findings **Security Analytics**.
6. Audit cluster : index pattern `security-auditlog-*`.

### Requêtes DSL utiles

**Pic d'erreurs par path :**
```json
GET microcrm-defects/_search
{
  "query": { "range": { "timestamp": { "gte": "now-15m" } } },
  "aggs": { "by_path": { "terms": { "field": "path.keyword", "size": 20 } } }
}
```

**Corrélation requestId :**
```json
GET microcrm-defects/_search
{
  "query": { "term": { "requestId.keyword": "<uuid>" } }
}
```

**Health down :**
```json
GET microcrm-server-state/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "event_type.keyword": "health" } },
        { "term": { "status.keyword": "down" } }
      ]
    }
  }
}
```

**Volume DELETE par IP :**
```json
GET microcrm-security-events/_search
{
  "query": {
    "bool": {
      "filter": [
        { "term": { "method.keyword": "DELETE" } },
        { "term": { "outcome.keyword": "success" } },
        { "range": { "timestamp": { "gte": "now-1h" } } }
      ]
    }
  },
  "aggs": { "by_ip": { "terms": { "field": "clientIp.keyword", "size": 10 } } }
}
```

---

## Synthèse

| Composant | Index | Quoi |
|-----------|-------|------|
| Back | `microcrm-defects` | Erreurs API |
| Back | `microcrm-security-events` | Journal d'accès (chaque requête) |
| Front | — | `X-Request-Id` uniquement |
| Fluent Bit | `microcrm-server-state` | Logs, health, métriques |
| Fluent Bit | `microcrm-security-events` | Backup lignes `SECURITY` |
| OpenSearch | `security-auditlog-*` | Audit admin |
| CI | `microcrm-security-events` | Sonar, build |
