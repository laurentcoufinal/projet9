# Définitions de tests — Orion MicroCRM (Gherkin)

Catalogue de scénarios BDD pour le contexte **ContactManagement** (voir [domaine.md](domaine.md)).

Ce document sert de **spécification vivante** : les scénarios `@existant` sont couverts par des tests automatisés actuels ; les scénarios `@a_implementer` décrivent les compléments cibles (API REST, UI dashboard, E2E).

---

## 1. Stratégie de test

### Pyramide

| Niveau | Technologie | CI | Rôle |
|--------|-------------|-----|------|
| Unitaire domaine | JUnit 5 | `./gradlew test` | Règles métier `Person`, `Organization` |
| Intégration persistance | `@DataJpaTest` | `./gradlew test` | Repositories JPA |
| Interface API | REST (à ajouter) | `./gradlew test` | Contrat HTTP Spring Data REST |
| Interface front | Jasmine + Karma + `HttpTestingController` | `npm run test:ci` | Services et composants Angular |
| E2E | Playwright / Cypress (à ajouter) | Optionnel post-Compose | Parcours navigateur + back réel |
| Smoke déploiement | `scripts/verify-docker.sh` | nightly / manuel | Santé stack Docker |

### Convention de tags

| Tag | Signification |
|-----|----------------|
| `@existant` | Couvert par un test automatisé (référence en fin de scénario) |
| `@a_implementer` | Spécification à automatiser |
| `@unite` | Test unitaire domaine |
| `@integration` | Test intégration JPA / Spring |
| `@api` | Test HTTP API REST |
| `@interface_front` | Test service ou composant Angular (mock HTTP) |
| `@e2e` | Test bout-en-bout navigateur |
| `@smoke` | Vérification déploiement / santé |

### Identifiants de scénarios

Format : `{COUCHE}-{DOMAINE}-{NN}` — ex. `DOM-PERS-01`, `API-ORG-03`, `E2E-05`.

---

## 2. Domaine — Contact (Person)

```gherkin
@existant @unite
Fonctionnalité: Modèle métier Person
  En tant que développeur du domaine ContactManagement
  Je veux garantir le comportement de l'entité Person
  Afin de préserver les invariants lors des évolutions DDD

  @DOM-PERS-01
  Scénario: Création d'un contact avec prénom, nom et email
    Étant donné que je crée un contact "John" "Doe" avec l'email "john@example.com"
    Quand je consulte ses attributs
    Alors le prénom est "John"
    Et le nom est "Doe"
    Et l'email est "john@example.com"
    # Réf: PersonTest.constructorWithFieldsSetsValues

  @DOM-PERS-02
  Scénario: Modification des champs via les accesseurs
    Étant donné un contact vide
    Quand je définis le prénom "Jane", le nom "Smith", l'email "jane@example.com", le téléphone "0102030405" et la bio "Developer"
    Alors les getters retournent ces valeurs
    # Réf: PersonTest.gettersAndSettersWork

  @DOM-PERS-03
  Scénario: Suppression sans organisations liées
    Étant donné un contact sans liste d'organisations
    Quand la méthode de détachement avant suppression est invoquée
    Alors aucune erreur n'est levée
    # Réf: PersonTest.removeFromOrganizationDoesNothingWhenListIsNull

  @DOM-PERS-04
  Scénario: Suppression avec détachement de toutes les organisations
    Étant donné un contact lié à deux organisations
    Quand la méthode de détachement avant suppression est invoquée
    Alors chaque organisation retire ce contact de sa liste
    # Réf: PersonTest.removeFromOrganizationRemovesPersonFromEachOrganization

  @a_implementer @unite
  Scénario: Refus d'ajouter deux fois le même membre dans une organisation
    Étant donné une organisation et un contact déjà membre
    Quand j'assigne à nouveau ce contact via assignMember
    Alors la liste des membres ne contient qu'une seule occurrence
    # Cible: évolution domaine.md (assignMember)

  @a_implementer @unite
  Scénario: Changement d'email invalide
    Étant donné un contact existant
    Quand je tente de définir un email au format invalide via changeEmail
    Alors une erreur de validation métier est levée
    # Cible: évolution domaine.md (changeEmail)
```

---

## 3. Domaine — Organisation (Organization)

```gherkin
@existant @unite
Fonctionnalité: Modèle métier Organization
  En tant que développeur du domaine ContactManagement
  Je veux gérer les membres d'une organisation
  Afin de maintenir la cohérence de l'appartenance

  @DOM-ORG-01
  Scénario: Ajout du premier membre quand la liste est vide
    Étant donné une organisation sans membres
    Quand j'ajoute un contact
    Alors la liste contient exactement ce contact
    # Réf: OrganizationTest.addPersonCreatesListWhenNull

  @DOM-ORG-02
  Scénario: Ajout d'un second membre
    Étant donné une organisation avec un membre
    Quand j'ajoute un autre contact
    Alors la liste contient deux membres
    # Réf: OrganizationTest.addPersonAppendsToExistingList

  @DOM-ORG-03
  Scénario: Retrait sur liste vide initialisée
    Étant donné une organisation sans membres
    Quand je retire un contact
    Alors la liste est vide
    # Réf: OrganizationTest.removePersonCreatesListWhenNull

  @DOM-ORG-04
  Scénario: Retrait d'un membre existant
    Étant donné une organisation avec un membre
    Quand je retire ce membre
    Alors la liste est vide
    # Réf: OrganizationTest.removePersonRemovesFromList

  @DOM-ORG-05
  Scénario: Nom de l'organisation
    Étant donné une organisation
    Quand je définis le nom "Orion"
    Alors le nom retourné est "Orion"
    # Réf: OrganizationTest.nameGetterAndSetterWork

  @DOM-ORG-06
  Scénario: Liste des membres via setter
    Étant donné une organisation et un contact
    Quand j'assigne la liste des membres via setPersons
    Alors getPersons contient ce contact
    # Réf: OrganizationTest.personsGetterAndSetterWork

  @a_implementer @unite
  Scénario: Pas de doublon lors de l'assignation d'un membre
    Étant donné une organisation contenant déjà un contact
    Quand j'appelle assignMember avec le même contact
    Alors le nombre de membres reste inchangé
    # Cible: évolution domaine.md
```

---

## 4. Intégration — Persistance

```gherkin
@existant @integration
Fonctionnalité: Persistance des contacts
  En tant que système MicroCRM
  Je veux retrouver un contact par email en base
  Afin de garantir l'unicité fonctionnelle côté données

  @INT-PERS-01
  Scénario: Recherche par email après insertion
    Étant donné un contact persisté avec l'email "jdoe@example.net"
    Quand je recherche par cet email via le repository
    Alors un contact est trouvé avec le même email
    # Réf: PersonRepositoryIntegrationTest.whenFindByEmail_thenReturnPerson

  @a_implementer @integration
  Scénario: Persistance d'une organisation avec liste de membres vide
    Étant donné une organisation nommée "Orion Inc"
    Quand je la persiste
    Alors je peux la recharger avec une liste de membres vide ou nulle

  @a_implementer @integration
  Scénario: Contact sans email obligatoire en base
    Étant donné un contact sans email renseigné
    Quand je tente de le persister
    Alors la validation échoue conformément aux contraintes JPA/Bean Validation
```

```gherkin
@existant @integration
Fonctionnalité: Démarrage de l'application
  @INT-APP-01
  Scénario: Le contexte Spring Boot se charge
    Étant donné l'application MicroCRM
    Quand le contexte Spring démarre en test
    Alors aucune erreur de configuration n'est levée
    # Réf: MicroCRMApplicationTests.contextLoads
```

---

## 4.1 Infrastructure web, exceptions et observabilité (OpenSearch)

Objectif : couverture SonarCloud **≥ 80 %** sur le backend Java (JaCoCo lignes). Les scénarios ci-dessous complètent la pyramide au-dessus du domaine et de la persistance.

```gherkin
@existant @unite
Fonctionnalité: Corrélation des requêtes HTTP (X-Request-Id)
  En tant qu'opérateur support
  Je veux tracer chaque requête API par un identifiant unique
  Afin de corréler logs, défauts et événements de sécurité

  @WEB-REQ-01
  Scénario: Conservation d'un X-Request-Id entrant
    Étant donné une requête HTTP avec l'en-tête X-Request-Id "incoming-id"
    Quand le filtre RequestIdFilter traite la requête
    Alors la réponse expose le même X-Request-Id
    Et l'attribut de requête requestId vaut "incoming-id"
    # Réf: RequestIdFilterTest.shouldPreserveIncomingRequestId

  @WEB-REQ-02
  Scénario: Génération d'un X-Request-Id manquant
    Étant donné une requête HTTP sans X-Request-Id
    Quand le filtre RequestIdFilter traite la requête
    Alors la réponse contient un X-Request-Id non vide
    Et l'attribut de requête requestId correspond à cet identifiant
    # Réf: RequestIdFilterTest.shouldGenerateRequestIdWhenMissing
```

```gherkin
@existant @unite
Fonctionnalité: Gestion centralisée des erreurs API
  En tant que consommateur de l'API REST
  Je veux des réponses JSON homogènes avec requestId
  Afin de diagnostiquer les incidents côté support

  @WEB-EXC-01
  Scénario: Erreur de validation Bean Validation (400)
    Étant donné une MethodArgumentNotValidException avec erreur sur le champ email
    Quand le GlobalExceptionHandler traite l'exception
    Alors le code HTTP est 400
    Et le corps contient message et requestId
    Et un défaut est indexé dans OpenSearch si le logger est disponible
    # Réf: GlobalExceptionHandlerTest.handleValidation_shouldReturnBadRequestWithFieldErrors

  @WEB-EXC-02
  Scénario: Violation de contrainte (400)
    Étant donné une ConstraintViolationException sur email
    Quand le handler traite l'exception
    Alors le code HTTP est 400
    # Réf: GlobalExceptionHandlerTest.handleConstraintViolation_shouldReturnBadRequest

  @WEB-EXC-03
  Scénario: Violation d'intégrité des données (409)
    Étant donné une DataIntegrityViolationException
    Quand le handler traite l'exception
    Alors le code HTTP est 409
    Et le message est "Data integrity violation"
    # Réf: GlobalExceptionHandlerTest.handleDataIntegrity_shouldReturnConflict

  @WEB-EXC-04
  Scénario: Erreur interne non gérée (500)
    Étant donné une Exception générique sans requestId connu
    Quand le handler traite l'exception
    Alors le code HTTP est 500
    Et requestId vaut "unknown"
    # Réf: GlobalExceptionHandlerTest.handleGeneric_shouldReturnInternalServerError

  @WEB-EXC-05
  Scénario: Troncature d'une stack trace très longue
    Étant donné une exception dont la stack trace dépasse 8192 caractères
    Quand le défaut est indexé
    Alors la stack trace stockée est tronquée avec l'indication "(truncated)"
    # Réf: GlobalExceptionHandlerTest.handleGeneric_shouldTruncateVeryLongStackTrace

  @WEB-EXC-06
  Scénario: Pas d'indexation si OpenSearch désactivé
    Étant donné qu'aucun OpenSearchDefectLogger n'est disponible
    Quand le handler traite une exception
    Alors aucun appel d'indexation n'est effectué
    # Réf: GlobalExceptionHandlerTest.shouldNotIndexDefectWhenLoggerUnavailable
```

```gherkin
@existant @unite @integration
Fonctionnalité: Observabilité OpenSearch (défauts et sécurité)
  En tant qu'équipe DevOps
  Je veux journaliser défauts et accès sensibles dans OpenSearch
  Afin d'alimenter le SIEM et les tableaux de bord

  @OBS-OS-01
  Scénario: Propriétés OpenSearch par défaut et personnalisées
    Étant donné un bean OpenSearchProperties
    Quand je lis ou modifie host, port, index et flags
    Alors les getters reflètent les valeurs configurées
    # Réf: OpenSearchPropertiesTest

  @OBS-OS-02
  Scénario: Bean OpenSearchClient créé quand opensearch.enabled=true
    Étant donné un contexte Spring Boot de test avec OpenSearch activé
    Quand le contexte démarre
    Alors un OpenSearchClient est injecté
    # Réf: OpenSearchConfigTest.openSearchClientBean_shouldBeCreatedWhenEnabled

  @OBS-OS-03
  Scénario: Indexation d'un défaut applicatif
    Étant donné un OpenSearchDefectLogger et un DefectDocument
    Quand indexDefect est appelé
    Alors le client OpenSearch reçoit une requête d'indexation
    # Réf: OpenSearchDefectLoggerTest.indexDefect_shouldCallOpenSearchClient

  @OBS-OS-04
  Scénario: Résilience si OpenSearch est indisponible (défauts)
    Étant donné un client OpenSearch qui lève une exception
    Quand indexDefect est appelé
    Alors l'exception n'est pas propagée à l'appelant
    # Réf: OpenSearchDefectLoggerTest.indexDefect_shouldNotPropagateException

  @OBS-OS-05
  Scénario: Indexation d'un événement de sécurité (accès)
    Étant donné un OpenSearchSecurityEventLogger
    Quand indexSecurityEvent est appelé
    Alors le client OpenSearch indexe l'événement
    # Réf: OpenSearchSecurityEventLoggerTest.indexSecurityEvent_shouldCallOpenSearchClient

  @OBS-OS-06
  Scénario: Journalisation d'accès DELETE sensible après requête
    Étant donné une requête DELETE sur /persons/1 avec X-Request-Id
    Quand SecurityAccessLogFilter a traité la requête
    Alors un SecurityEventDocument sensible est indexé avec outcome "success"
    # Réf: SecurityAccessLogFilterTest.shouldIndexAccessEventAfterRequest

  @OBS-OS-07
  Scénario: Exclusion des chemins Actuator du filtre sécurité
    Étant donné une requête GET /actuator/health
    Alors le filtre ne s'applique pas
    # Réf: SecurityAccessLogFilterTest.shouldSkipActuatorPaths

  @OBS-OS-08
  Scénario: IP client sans en-tête X-Forwarded-For
    Étant donné une requête sans X-Forwarded-For
    Alors l'IP résolue est l'adresse distante de la requête
    # Réf: SecurityAccessLogFilterTest.resolveClientIp_usesRemoteAddrWhenNoForwardedHeader

  @OBS-OS-09
  Scénario: Requête sans X-Request-Id côté client
    Étant donné une requête GET /persons sans en-tête X-Request-Id
    Quand le filtre de sécurité journalise l'accès
    Alors requestId vaut "unknown" et requestIdProvided est false
    # Réf: SecurityAccessLogFilterTest.shouldIndexEventWithoutClientRequestId

  @OBS-OS-10
  Scénario: Troncature d'un User-Agent trop long
    Étant donné un User-Agent de plus de 512 caractères
    Quand l'événement de sécurité est construit
    Alors le userAgent stocké fait au plus 512 caractères
    # Réf: SecurityAccessLogFilterTest.shouldTruncateLongUserAgent
```

---

## 5. API REST — Contacts (Person)

Base URL : `{API}/persons` (Spring Data REST, format HAL).

```gherkin
@a_implementer @api
Fonctionnalité: API REST des contacts
  En tant que client HTTP (front Angular ou outil externe)
  Je veux manipuler les contacts via l'API
  Afin d'alimenter l'interface CRM

  @API-PERS-01
  Scénario: Lister tous les contacts
    Quand j'envoie une requête GET sur "/persons"
    Alors le code HTTP est 200
    Et le corps contient "_embedded.persons" au format HAL

  @API-PERS-02
  Scénario: Consulter un contact existant
    Étant donné un contact persisté avec l'identifiant 1
    Quand j'envoie GET sur "/persons/1"
    Alors le code HTTP est 200
    Et le corps contient firstName, lastName et email

  @API-PERS-03
  Scénario: Contact inexistant
    Quand j'envoie GET sur "/persons/99999"
    Alors le code HTTP est 404

  @API-PERS-04
  Scénario: Créer un contact valide
    Quand j'envoie POST sur "/persons" avec un JSON contenant firstName, lastName et email valides
    Alors le code HTTP est 201
    Et la réponse contient un identifiant généré

  @API-PERS-05
  Scénario: Créer un contact sans email
    Quand j'envoie POST sur "/persons" sans champ email
    Alors le code HTTP est 400

  @API-PERS-06
  Scénario: Mettre à jour un contact
    Étant donné un contact persisté avec l'identifiant 1
    Quand j'envoie PUT sur "/persons/1" avec un nouvel email
    Alors le code HTTP est 200
    Et GET sur "/persons/1" retourne le nouvel email

  @API-PERS-07
  Scénario: Supprimer un contact
    Étant donné un contact persisté avec l'identifiant 1
    Quand j'envoie DELETE sur "/persons/1"
    Alors le code HTTP est 200 ou 204
    Et GET sur "/persons/1" retourne 404

  @API-PERS-08
  Scénario: Lister les organisations d'un contact
    Étant donné un contact lié à une organisation
    Quand j'envoie GET sur "/persons/{id}/organizations"
    Alors le code HTTP est 200
    Et le corps contient "_embedded.organizations"
```

---

## 6. API REST — Organisations (Organization)

Base URL : `{API}/organizations`.

```gherkin
@a_implementer @api
Fonctionnalité: API REST des organisations
  En tant que client HTTP
  Je veux manipuler les organisations et leurs membres
  Afin de gérer les comptes clients

  @API-ORG-01
  Scénario: Lister toutes les organisations
    Quand j'envoie GET sur "/organizations"
    Alors le code HTTP est 200
    Et le corps contient "_embedded.organizations"

  @API-ORG-02
  Scénario: Consulter une organisation existante
    Étant donné une organisation persistée avec l'identifiant 2
    Quand j'envoie GET sur "/organizations/2"
    Alors le code HTTP est 200
    Et le corps contient le nom de l'organisation

  @API-ORG-03
  Scénario: Organisation inexistante
    Quand j'envoie GET sur "/organizations/99999"
    Alors le code HTTP est 404

  @API-ORG-04
  Scénario: Créer une organisation
    Quand j'envoie POST sur "/organizations" avec un nom non vide
    Alors le code HTTP est 201
    Et la réponse contient un identifiant

  @API-ORG-05
  Scénario: Mettre à jour une organisation
    Étant donné une organisation persistée
    Quand j'envoie PUT avec un nouveau nom
    Alors le code HTTP est 200

  @API-ORG-06
  Scénario: Supprimer une organisation
    Étant donné une organisation persistée
    Quand j'envoie DELETE sur "/organizations/{id}"
    Alors le contact n'est plus accessible via GET

  @API-ORG-07
  Scénario: Lister les membres d'une organisation
    Étant donné une organisation avec au moins un membre
    Quand j'envoie GET sur "/organizations/{id}/persons"
    Alors le code HTTP est 200
    Et le corps contient "_embedded.persons"

  @API-ORG-08
  Scénario: Associer un contact à une organisation (uri-list)
    Étant donné une organisation 1 et un contact 2 existants
    Quand j'envoie PUT sur "/organizations/1/persons" avec Content-Type "text/uri-list" et l'URI du contact
    Alors le code HTTP est 200 ou 201
    Et GET sur "/organizations/1/persons" inclut le contact 2

  @API-ORG-09
  Scénario: Retirer l'appartenance d'un contact
    Étant donné un contact 2 membre de l'organisation 1
    Quand j'envoie DELETE sur "/persons/2/organizations/1"
    Alors le code HTTP est 200 ou 204
    Et GET sur "/persons/2/organizations" ne contient plus l'organisation 1
```

---

## 7. Interface front — Services HTTP

```gherkin
@existant @interface_front
Fonctionnalité: Service Angular PersonService
  En tant qu'interface utilisateur
  Je veux appeler l'API contacts via HttpClient
  Afin d'afficher et modifier les fiches

  @IF-PERS-01
  Scénario: Récupérer la liste des contacts (HAL)
    Quand j'appelle fetchAll
    Alors une requête GET est envoyée vers "/persons"
    Et les contacts du payload "_embedded.persons" sont retournés
    # Réf: person.service.spec — fetchAll should return persons from HAL payload

  @IF-PERS-02
  Scénario: Charger un contact et ses organisations
    Quand j'appelle fetchById avec l'identifiant 1
    Alors GET "/persons/1" puis GET "/persons/1/organizations" sont exécutés
    Et le contact retourné contient ses organisations
    # Réf: person.service.spec — fetchById should load person and organizations

  @IF-PERS-03
  Scénario: Créer un contact (POST)
    Étant donné un contact sans identifiant
    Quand j'appelle save
    Alors POST "/persons" est envoyé
    Et fetchById est enchaîné pour recharger les organisations
    # Réf: person.service.spec — save should POST when id is undefined

  @IF-PERS-04
  Scénario: Mettre à jour un contact (PUT)
    Étant donné un contact avec identifiant 3
    Quand j'appelle save
    Alors PUT "/persons/3" est envoyé
    # Réf: person.service.spec — save should PUT when id is set

  @IF-PERS-05
  Scénario: Supprimer un contact
    Quand j'appelle deleteById avec l'identifiant 7
    Alors DELETE "/persons/7" est envoyé
    # Réf: person.service.spec — deleteById should call DELETE
```

```gherkin
@existant @interface_front
Fonctionnalité: Service Angular OrganizationService
  @IF-ORG-01
  Scénario: Récupérer la liste des organisations (HAL)
    Quand j'appelle fetchAll
    Alors GET "/organizations" est envoyé
    Et les organisations "_embedded.organizations" sont retournées
    # Réf: organization.service.spec — fetchAll

  @IF-ORG-02
  Scénario: Charger une organisation et ses membres
    Quand j'appelle fetchById avec l'identifiant 2
    Alors GET "/organizations/2" puis GET "/organizations/2/persons"
    # Réf: organization.service.spec — fetchById

  @IF-ORG-03
  Scénario: Créer une organisation (POST)
    Étant donné une organisation sans identifiant
    Quand j'appelle save
    Alors POST "/organizations" est envoyé
    # Réf: organization.service.spec — save should POST

  @IF-ORG-04
  Scénario: Mettre à jour une organisation (PUT)
    Étant donné une organisation avec identifiant 3
    Quand j'appelle save
    Alors PUT "/organizations/3" est envoyé
    # Réf: organization.service.spec — save should PUT

  @IF-ORG-05
  Scénario: Supprimer une organisation
    Quand j'appelle deleteById avec l'identifiant 9
    Alors DELETE "/organizations/9" est envoyé
    # Réf: organization.service.spec — deleteById

  @IF-ORG-06
  Scénario: Associer un contact à une organisation
    Quand j'appelle addPerson avec orgId 1 et personId 2
    Alors PUT "/organizations/1/persons" est envoyé avec Content-Type "text/uri-list"
    # Réf: organization.service.spec — addPerson should PUT uri-list

  @IF-ORG-07
  Scénario: Retirer un contact d'une organisation
    Quand j'appelle removePerson avec orgId 1 et personId 2
    Alors DELETE "/persons/2/organizations/1" est envoyé
    # Réf: organization.service.spec — removePerson
```

---

## 8. Interface front — Composants UI

```gherkin
@existant @interface_front
Fonctionnalité: Coquille applicative AppComponent
  @UI-APP-01
  Scénario: Le composant racine est instanciable
    Quand le composant App est créé
    Alors il est truthy
    # Réf: app.component.spec — should create the app

  @UI-APP-02
  Scénario: Titre de l'application
    Alors le titre du composant est "MicroCRM"
    # Réf: app.component.spec — should have the MicroCRM title

  @UI-APP-03
  Scénario: Affichage du titre dans le template
    Quand le template est rendu
    Alors le h1 contient "MicroCRM"
    # Réf: app.component.spec — should render title
```

```gherkin
@existant @interface_front
Fonctionnalité: Tableau de bord MainDashboardComponent
  @UI-DASH-01
  Scénario: Le composant dashboard est instanciable
    Quand MainDashboardComponent est créé
    Alors le composant est truthy
    # Réf: main-dashboard.component.spec — should create

  @a_implementer @interface_front
  Scénario: Affichage des listes contacts et organisations
    Étant donné des données mockées pour persons et organizations
    Quand le dashboard est affiché
    Alors le tableau Persons contient les noms des contacts
    Et le tableau Organizations contient les noms des organisations

  @a_implementer @interface_front
  Scénario: État vide sans contact
    Étant donné aucune personne en base
    Quand le dashboard est affiché
    Alors le message "No person yet" est visible
    Et un lien vers la création est proposé

  @a_implementer @interface_front
  Scénario: Lien de création organisation cohérent
    Étant donné le dashboard sans organisation
    Quand je clique sur le lien de création dans la colonne Organizations
    Alors je suis redirigé vers "/organizations/new"
    # Note: le template actuel pointe vers "organization/new" (sans s) — incohérence à corriger
```

```gherkin
@existant @interface_front
Fonctionnalité: Fiche contact PersonDetailsComponent
  @UI-PERS-01
  Scénario: Mode création sur la route persons/new
    Étant donné la route avec personId "new"
    Quand le composant s'initialise
    Alors isNew est vrai
    # Réf: person-details.component.spec — ngOnInit should set isNew

  @UI-PERS-02
  Scénario: Chargement d'un contact existant
    Étant donné la route avec personId "3"
    Quand le composant s'initialise
    Alors fetchById(3) est appelé
    Et isNew est faux
    Et le prénom affiché est "John"
    # Réf: person-details — should load existing person

  @UI-PERS-03
  Scénario: Enregistrement et redirection après création
    Étant donné un contact sauvegardé avec l'id 10
    Quand j'appelle savePerson
    Alors la navigation vers ["persons", 10] est déclenchée
    # Réf: person-details — savePerson should navigate when creating

  @UI-PERS-04
  Scénario: Suppression et retour à l'accueil
    Étant donné un contact avec l'id 5
    Quand j'appelle deletePerson
    Alors deleteById(5) est appelé
    Et la navigation vers [""] est déclenchée
    # Réf: person-details — deletePerson should navigate home

  @UI-PERS-05
  Scénario: Ajout d'une organisation sélectionnée
    Étant donné un contact id 1 et une organisation id 2 sélectionnée
    Quand j'appelle addSelectedOrganization
    Alors addPerson(2, 1) est appelé sur OrganizationService
    # Réf: person-details — addSelectedOrganization

  @a_implementer @interface_front
  Scénario: Bouton Save désactivé si formulaire invalide
    Étant donné un formulaire contact sans prénom
    Alors le bouton Save est désactivé

  @a_implementer @interface_front
  Scénario: Retrait d'une organisation depuis la fiche
    Étant donné un contact membre d'une organisation affichée
    Quand je retire cette organisation
    Alors removePerson est appelé et la liste est rafraîchie
```

```gherkin
@existant @interface_front
Fonctionnalité: Fiche organisation OrganizationDetailsComponent
  @UI-ORG-01
  Scénario: Mode création sur la route organizations/new
    Étant donné la route avec orgId "new"
    Alors isNew est vrai
    # Réf: organization-details — ngOnInit should set isNew

  @UI-ORG-02
  Scénario: Chargement d'une organisation existante
    Étant donné la route avec orgId "2"
    Alors fetchById(2) est appelé et le nom est "Orion"
    # Réf: organization-details — should load existing organization

  @UI-ORG-03
  Scénario: Enregistrement et redirection après création
    Quand saveOrg est appelé avec une org id 8
    Alors navigation vers ["organizations", 8]
    # Réf: organization-details — saveOrg should navigate

  @UI-ORG-04
  Scénario: Suppression et retour à l'accueil
    Étant donné une organisation id 4
    Quand deleteOrg est appelé
    Alors deleteById(4) et navigation vers [""]
    # Réf: organization-details — deleteOrg should navigate home
```

---

## 9. Tests bout-en-bout (E2E)

Prérequis : stack Docker (`docker compose up`) ou back + front en local. Outil recommandé : **Playwright** ou **Cypress**.

```gherkin
@a_implementer @e2e
Fonctionnalité: Parcours utilisateur CRM
  En tant qu'utilisateur métier Orion
  Je veux gérer contacts et organisations via le navigateur
  Afin d'utiliser le MicroCRM en conditions réelles

  @E2E-01
  Scénario: Affichage du tableau de bord
    Étant donné l'application déployée et accessible
    Quand j'ouvre la page d'accueil
    Alors je vois le titre "Persons"
    Et je vois le titre "Organizations"

  @E2E-02
  Scénario: Créer un nouveau contact
    Étant donné le tableau de bord
    Quand je clique sur le bouton "+" de la section Persons
    Et je remplis prénom, nom et email valides
    Et je clique sur Save
    Alors l'URL contient "/persons/"
    Et la fiche affiche les informations saisies

  @E2E-03
  Scénario: Modifier un contact existant
    Étant donné une fiche contact existante
    Quand je modifie l'email
    Et je clique sur Save
    Alors la fiche affiche le nouvel email

  @E2E-04
  Scénario: Supprimer un contact
    Étant donné une fiche contact existante
    Quand je clique sur Delete
    Alors je suis redirigé vers le tableau de bord
    Et le contact n'apparaît plus dans la liste Persons

  @E2E-05
  Scénario: Créer une nouvelle organisation
    Étant donné le tableau de bord
    Quand je clique sur le bouton "+" de la section Organizations
    Et je saisis un nom d'organisation
    Et je clique sur Save
    Alors l'URL contient "/organizations/"
    Et la fiche affiche le nom saisi

  @E2E-06
  Scénario: Associer un contact à une organisation
    Étant donné une fiche contact et au moins une organisation en base
    Quand je sélectionne une organisation dans la liste
    Et j'ajoute cette organisation
    Alors l'organisation apparaît dans la section organisations de la fiche

  @E2E-07
  Scénario: Dissocier un contact d'une organisation
    Étant donné un contact membre d'une organisation affichée sur sa fiche
    Quand je retire cette organisation
    Alors elle n'apparaît plus sur la fiche contact
```

```gherkin
@existant @smoke
Fonctionnalité: Smoke déploiement Docker
  @SMK-01
  Scénario: Santé du backend
    Étant donné la stack Docker démarrée
    Quand j'appelle GET "http://localhost:8080/persons"
    Alors la réponse est HTTP 200
  # Réf: scripts/verify-docker.sh — curl backend

  @SMK-02
  Scénario: Accessibilité du frontend
    Étant donné la stack Docker démarrée
    Quand j'appelle GET "http://localhost:80/"
    Alors le code HTTP est 200
  # Réf: scripts/verify-docker.sh — curl front

  @a_implementer @smoke @e2e
  Scénario: Parcours minimal post-déploiement
    Étant donné la stack Docker démarrée
    Quand j'ouvre le frontend dans un navigateur headless
    Alors la page d'accueil MicroCRM se charge sans erreur console bloquante
```

---

## 10. Matrice de traçabilité complète

| ID | Tag | Test automatisé / artefact |
|----|-----|---------------------------|
| DOM-PERS-01 | @existant | `PersonTest.constructorWithFieldsSetsValues` |
| DOM-PERS-02 | @existant | `PersonTest.gettersAndSettersWork` |
| DOM-PERS-03 | @existant | `PersonTest.removeFromOrganizationDoesNothingWhenListIsNull` |
| DOM-PERS-04 | @existant | `PersonTest.removeFromOrganizationRemovesPersonFromEachOrganization` |
| DOM-PERS-05 | @a_implementer | — |
| DOM-PERS-06 | @a_implementer | — |
| DOM-ORG-01 | @existant | `OrganizationTest.addPersonCreatesListWhenNull` |
| DOM-ORG-02 | @existant | `OrganizationTest.addPersonAppendsToExistingList` |
| DOM-ORG-03 | @existant | `OrganizationTest.removePersonCreatesListWhenNull` |
| DOM-ORG-04 | @existant | `OrganizationTest.removePersonRemovesFromList` |
| DOM-ORG-05 | @existant | `OrganizationTest.nameGetterAndSetterWork` |
| DOM-ORG-06 | @existant | `OrganizationTest.personsGetterAndSetterWork` |
| DOM-ORG-07 | @a_implementer | — |
| INT-PERS-01 | @existant | `PersonRepositoryIntegrationTest.whenFindByEmail_thenReturnPerson` |
| INT-PERS-02 | @a_implementer | — |
| INT-PERS-03 | @a_implementer | — |
| INT-APP-01 | @existant | `MicroCRMApplicationTests.contextLoads` |
| WEB-REQ-01 … 02 | @existant | `RequestIdFilterTest` |
| WEB-EXC-01 … 06 | @existant | `GlobalExceptionHandlerTest` |
| OBS-OS-01 … 10 | @existant | `OpenSearchPropertiesTest`, `OpenSearchConfigTest`, `OpenSearchDefectLoggerTest`, `OpenSearchSecurityEventLoggerTest`, `SecurityAccessLogFilterTest` |
| API-PERS-01 … 08 | @a_implementer | — (REST Assured / `@SpringBootTest` + TestRestTemplate) |
| API-ORG-01 … 09 | @a_implementer | — |
| IF-PERS-01 … 05 | @existant | `person.service.spec.ts` |
| IF-ORG-01 … 07 | @existant | `organization.service.spec.ts` |
| UI-APP-01 … 03 | @existant | `app.component.spec.ts` |
| UI-DASH-01 | @existant | `main-dashboard.component.spec.ts` |
| UI-DASH-02 … 04 | @a_implementer | — |
| UI-PERS-01 … 05 | @existant | `person-details.component.spec.ts` |
| UI-PERS-06 … 07 | @a_implementer | — |
| UI-ORG-01 … 04 | @existant | `organization-details.component.spec.ts` |
| E2E-01 … 07 | @a_implementer | — (Playwright / Cypress) |
| SMK-01 | @existant | `verify-docker.sh` (backend) |
| SMK-02 | @existant | `verify-docker.sh` (frontend) |
| SMK-03 | @a_implementer | — |

### Synthèse de couverture

| Couche | Scénarios | @existant | @a_implementer |
|--------|-----------|-----------|----------------|
| Domaine | 13 | 10 | 3 |
| Intégration | 4 | 2 | 2 |
| Web / exceptions / observabilité | 18 | 18 | 0 |
| API REST | 17 | 0 | 17 |
| Interface front (services) | 12 | 12 | 0 |
| Interface front (UI) | 16 | 10 | 6 |
| E2E | 7 | 0 | 7 |
| Smoke | 3 | 2 | 1 |
| **Total** | **90** | **54** | **36** |

---

## 11. Recommandations d'outillage (implémentation future)

| Besoin | Outil suggéré | Emplacement |
|--------|---------------|-------------|
| Tests API REST | REST Assured ou `TestRestTemplate` + `@SpringBootTest(webEnvironment = RANDOM_PORT)` | `back/src/test/.../api/` |
| Tests E2E | Playwright (`npx playwright test`) | `front/e2e/` ou racine `P7-FSJA/e2e/` |
| Exécution BDD optionnelle | Cucumber JVM + fichiers `.feature` dérivés de ce document | `back/src/test/resources/features/` |
| CI E2E | Job GitHub Actions après `docker compose up` | `.github/workflows/ci.yml` |

---

## 12. Références

| Document | Lien |
|----------|------|
| Modèle métier DDD | [domaine.md](domaine.md) |
| Pipeline et tests CI | [documentation-technique.md](documentation-technique.md) §4 |
| Workflow CI | `../.github/workflows/ci.yml` |
| Smoke Docker | [scripts/verify-docker.sh](scripts/verify-docker.sh) |

---

*Dernière mise à jour : ajout section 4.1 (RequestId, GlobalExceptionHandler, OpenSearch, SecurityAccessLogFilter) — couverture backend JaCoCo cible ≥ 80 % (SonarCloud).*
La couverture globale est à 64,9 % — principalement à cause du package exception et d'OpenSearch. J'examine les fichiers peu couverts pour ajouter des tests.