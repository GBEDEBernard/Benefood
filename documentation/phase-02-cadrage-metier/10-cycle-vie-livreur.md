# J10 — Cycle de vie du livreur

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Validé — **Source :** Plan directeur V1.2, Phase 02, J10

---

## 1. Objet

Définir la machine à états du livreur depuis la candidature jusqu'à la suspension, en distinguant le **livreur indépendant** et le **livreur Béninfood**.

## 2. Types de livreur

| Type | Code | Mode de recrutement | Modèle de rémunération (détail en J14) |
|------|------|---------------------|----------------------------------------|
| Livreur indépendant | `independent` | Candidature volontaire + validation porteuse | À la course (part livraison) |
| Livreur Béninfood | `beninfood` | Embauche par Béninfood (compte créé par l'interne) | Salaire/contrat Béninfood (+ variables possibles) |

## 3. Statuts du livreur

| Statut | Code | Description |
|--------|------|-------------|
| Candidat | `candidate` | Profil livreur créé, dossier en attente de validation |
| En validation | `pending_validation` | Documents soumis, vérification porteuse en cours |
| Validé | `validated` | Dossier accepté, activité pas encore commencée |
| Actif | `active` | Peut passer online/offline et recevoir des courses |
| Suspendu | `suspended` | Blocage temporaire (incident, litige, non-respect règles) |
| Fermé | `closed` | Retrait définitif |

> Le statut de **disponibilité** (`online`/`offline`) est un attribut **volatil** séparé du statut du compte (décrit en section 4.5).

## 4. Transitions autorisées

```
candidate ──▶ pending_validation ──▶ validated ──▶ active ──▶ suspended
      │               │                                            │
      └───────────────┘                                            ▼
      (rejet => closed) / retrait volontaire                     closed
```

### 4.1 Livreur indépendant

| De | Vers | Déclencheur | Acteur |
|----|------|-------------|--------|
| — | `candidate` | Candidature complète (profil + documents de base) | Livreur |
| `candidate` | `pending_validation` | Soumission des documents (pièce d'identité, permis/véhicule, assurance…) | Livreur |
| `pending_validation` | `validated` | Validation du dossier | Porteuse |
| `pending_validation` | `closed` | Rejet (dossier non conforme, fraude) | Porteuse |
| `validated` | `active` | Activation (intègre le pool de livreurs) | Porteuse |
| `active` | `suspended` | Incident, litige, non-respect des règles | Porteuse |
| `suspended` | `active` | Levée de suspension | Porteuse |
| `suspended` / `active` / `validated` | `closed` | Retrait volontaire ou fermeture définitive | Livreur / Porteuse |

### 4.2 Livreur Béninfood

- Le compte est créé **par l'interne Béninfood** (porteuse ou admin technique), pas par candidature publique.
- Par défaut, le livreur Béninfood est `validated`, puis il est activé par la porteuse.
- Les mêmes statuts `active` / `suspended` / `closed` s'appliquent.
- Le livreur Béninfood ne passe **pas** par l'étape candidature/validation de documents publics.

## 5. Règles détaillées

### 5.1 Disponibilité (online/offline)
1. Seul un livreur **actif** peut passer en `online`.
2. `online` signifie « prêt à recevoir des affectations de course ».
3. Un livreur `online` peut passer `offline` à tout moment ; les courses déjà affectées/acceptées restent à terminer.
4. Un livreur avec une course en cours ne peut pas passer `offline` tant que la course n'est pas terminée ou annulée (règle de cohérence).
5. Changements d'état enregistrés et horodatés (`delivery_status_history`).

### 5.2 Affectation de course
1. L'affectation se fait selon les règles choisies (définies à la Phase 13) : livraison à l'offre, attributions automatiques par proximité/zone, ou affectation manuelle de la porteuse.
2. Une course est proposée : le livreur peut l'**accepter** ou la **refuser** (durée de proposition limitée et configurable).
3. Refuser une course n'affecte pas le statut du compte, mais peut affecter les règles d'accord de la porteuse (trace).
4. Les conflits d'affectation sont gérés par la règle « une course = un livreur » ; une course ne peut pas être assignée à deux livreurs simultanément.

### 5.3 Suspension
1. Motif obligatoire et auditable.
2. Effets immédiats :
   - Le livreur passe hors ligne (`online` désactivé).
   - Les courses en cours ne sont **pas** abandonnées brutalement : elles passent en incident/retour vendeur selon les règles (Phase 13/14) ;
   - Le livreur est notifié du motif.
3. Levée de suspension par la porteuse après traitement.

### 5.4 Fermeture
1. Plus de nouvelles affectations.
2. Les gains déjà acquis restent consultables en lecture seule.
3. Les courses en cours sont gérées (réaffectation) selon les règles Phase 13/14.

## 6. Notifications associées

| Événement | Destinataire | Canal |
|-----------|--------------|-------|
| Candidature reçue | Livreur | Email + push |
| Demande de documents | Livreur | Email + push |
| Dossier validé | Livreur | Email + push |
| Activation | Livreur | Email + push |
| Suspension (avec motif) | Livreur | Email + push |
| Fermeture | Livreur | Email |
| Nouvelle course proposée | Livreur | Push (priorité haute) |

## 7. Critères d'acceptation

- [ ] Les statuts `candidate` → `pending_validation` → `validated` → `active` (+ `suspended`, `closed`) sont implémentés
- [ ] Livreur indépendant et Béninfood sont distingués dès l'inscription
- [ ] Disponibilité `online`/`offline` séparée du statut du compte
- [ ] Une course = un livreur (pas de double affectation)
- [ ] Suspension/fermeture = plus de nouvelles courses + gestion des courses en cours
- [ ] Historisation et notifications systématiques