# J09 — Cycle de vie du vendeur

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Validé — **Source :** Plan directeur V1.2, Phase 02, J09

---

## 1. Objet

Définir la machine à états du vendeur (la personne/entité commerciale) depuis l'inscription jusqu'à la fermeture définitive du compte boutique.

## 2. Statistiques des statuts

| Statut | Code | Description |
|--------|------|-------------|
| Inscrit | `registered` | Profil vendeur créé, en attente de vérification |
| En vérification | `pending_verification` | Documents envoyés, contrôles de la porteuse en cours |
| Vérifié | `verified` | Documents valides, boutique encore désactivée |
| Actif | `active` | Boutique ouverte, visible et opérationnelle |
| Suspendu | `suspended` | Compte bloqué temporairement par la porteuse |
| Fermé | `closed` | Compte définitivement fermé (arrêt d'activité) |

> **Note technique :** le statut du « vendeur » (entité) et le statut « ouvert/fermé » de la boutique (établissement) sont **deux attributs distincts**. Le statut de la boutique est géré dans J55 (Phase 07) ; le présent document ne traite que du statut du compte vendeur.

## 3. Transitions autorisées

```
registered ──▶ pending_verification ──▶ verified ──▶ active ──▶ suspended
      │                │                                                │
      └───────────────┘                                                ▼
   (rejet => fermé / fermeture volontaire)                           closed
```

| De | Vers | Déclencheur | Acteur autorisé |
|----|------|-------------|-----------------|
| — | `registered` | Inscription complète dans l'app | Vendeur |
| `registered` | `pending_verification` | Soumission des documents (pièce d'identité, registre commerce, photo boutique…) | Vendeur |
| `pending_verification` | `verified` | Validation des documents conforme | Porteuse |
| `pending_verification` | `closed` | Rejet définitif (fraude, documents non conformes malgré relance) | Porteuse |
| `verified` | `active` | Activation officielle de la boutique (boutique configurée + approuvée) | Porteuse / automatique |
| `active` | `suspended` | Fraude, litige, non-respect des règles, demande porteuse | Porteuse |
| `suspended` | `active` | Levée de suspension après traitement | Porteuse |
| `suspended` | `closed` | Fermeture définitive | Porteuse |
| `active` | `closed` | Fermeture volontaire ou décision de retrait de la plateforme | Vendeur / Porteuse |
| `verified` | `closed` | Abandon avant activation | Vendeur / Porteuse |

## 4. Règles détaillées

### 4.1 Inscription (`registered`)
1. Le vendeur s'inscrit avec son compte utilisateur (email/numéro + mot de passe).
2. L'utilisateur reçoit le rôle `vendeur` (cumulable avec d'autres rôles).
3. Un **profil vendeur** est créé avec les informations légales/commerciales (raison sociale, IFU éventuel, contact, localisation).
4. Le statut initial est `registered`.

### 4.2 Vérification (`pending_verification`)
1. Le vendeur soumet les documents obligatoires (liste validée à la Phase 07).
2. Tant que les documents ne sont pas soumis, le vendeur reste `registered`.
3. Un délai de relance s'applique : si les documents ne sont pas complets sous X jours après inscription, un rappel est envoyé (voir Phase 15).
4. La vérification est faite par la porteuse via le back-office.

### 4.3 Activation (`active`)
1. Le vendeur doit au préalable avoir configuré sa boutique (nom, description, images, adresse, horaires) — Phase 07.
2. L'activation peut être faite par la porteuse ou par workable automatique si la politique retenue le permet.
3. Seuls les vendeurs `active` apparaissent dans le catalogue client et peuvent recevoir des commandes.

### 4.4 Suspension (`suspended`)
1. Une suspension est motivée (motif obligatoire) et auditable.
2. Effets immédiats :
   - La boutique disparaît du catalogue client.
   - Les commandes en cours ne sont **pas** automatiquement annulées ; elles sont traitées selon les règles d'annulation (J12).
   - Le vendeur est notifié avec le motif.
3. Le vendeur suspendu ne peut pas créer/modifier ses produits.

### 4.5 Fermeture (`closed`)
1. Cas de figure : fermeture volontaire, rejet, retrait de la plateforme, incapacité définitive.
2. Effets :
   - Le compte vendeur n'est plus accessible en mode Vendeur.
   - Les données financières restent accessibles en lecture seule (historique) pour la régularisation des paiements en cours.
   - Aucune nouvelle commande n'entre.
   - Les commandes en cours suivent le workflow de J12 (annulation/remboursement si nécessaire).
3. La fermeture est irréversible (sauf exception validée par la porteuse).

## 5. Notifications associées

| Événement | Destinataire | Canal |
|-----------|--------------|-------|
| Inscription prise en compte | Vendeur | Email + push (si app) |
| Demande de documents | Vendeur | Email + push |
| Vérifié | Vendeur | Email + push |
| Activé (boutique opérationnelle) | Vendeur | Email + push |
| Suspendu (avec motif) | Vendeur | Email + push |
| Fermé | Vendeur | Email |
| Relance documents | Vendeur | Email + push |

## 6. Données à historiser

- `vendor_status_history` : changement de statut, auteur, date, motif, référence du document.

## 7. Critères d'acceptation

- [ ] Les 5 statuts sont implémentés (registered, pending_verification, verified, active, suspended, closed)
- [ ] Chaque transition est validée par les bons acteurs
- [ ] Une suspension / fermeture empêche toute nouvelle vente
- [ ] Les commandes en cours sont gérées selon J12
- [ ] Chaque changement d'état est audité et notifié