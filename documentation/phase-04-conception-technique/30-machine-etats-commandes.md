# J30 — Machine à états des commandes

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J30 + J11

---

## 1. Définition technique

Implémentation d'une **state machine dédiée** dans `app/Support/StateMachines/OrderStateMachine` (ou package), avec transitions validées par Policy + motif/événement.

Statuts (`orders.status`) — enum `OrderStatus` :
`draft` `awaiting_payment` `paid` `accepted` `preparing` `ready` `assigned` `picked_up` `in_delivery` `delivered` `cancelled` `refunded`

## 2. Table des transitions autorisées

| # | From | To | Trigger | Acteur | Método / événements |
|---|------|-----|---------|--------|---------------------|
| T1 | — | draft | create | Client | OrderService::createFromCart |
| T2 | draft | awaiting_payment | quote+confirm | Client | snapshot items, verrou montants, deadline |
| T3 | awaiting_payment | paid | webhook OK | Système | PaymentService::confirm (idempotent) |
| T4 | awaiting_payment | cancelled | client abandon | Client | motif requis optionnel |
| T5 | awaiting_payment | cancelled | expiration deadline | Système | job ScheduledJob, libère stocks |
| T6 | paid | accepted | accept | Vendeur | (timeout → rappel/incident) |
| T7 | paid | cancelled | refuse | Vendeur | **motif obligatoire** |
| T8 | paid | cancelled | annulation client (rétraction) | Client | règle sans frais (J12) |
| T9 | accepted | preparing | start | Vendeur | — |
| T10 | preparing | ready | mark ready | Vendeur | — |
| T11 | ready | assigned | assign driver | Système/Porteuse | DeliveryService::assign |
| T12 | assigned | picked_up | pickup confirm | Livreur | preuve/horodatage |
| T13 | picked_up | in_delivery | start delivery | Livreur | — |
| T14 | in_delivery | delivered | deliver confirm | Livreur | **preuve obligatoire** (code/photo) |
| T15 | (context) | cancelled | cancel | selon J12 | motif + détermination refund |
| T16 | cancelled | refunded | refund executed | Système | PaymentService::refund si dû |

## 3. Transitions INTERDITES (exemples à coder en négatif)

- `paid` → `preparing` (il faut `accepted` d'abord)
- `draft` → `delivered`
- `delivered` → `paid` (ni retour en arrière)
- `assigned` → `preparing` (le vendeur n'agit plus après affectation hors exceptions)
- Toute transition vers `draft` (terminal côté sens)

## 4. Design technique (Laravel)

- La seule "source de vérité" du statut est `orders.status`, mis via une **méthode centrale** `OrderStateMachine::transitionTo($order, OrderStatus $to, $actor, ?string $reason)`.
- Chaque `transitionTo` :
  1. vérifie que la transition est dans la table des transitions autorisées ;
  2. exécute la `Policy` correspondante (permission de l'acteur) ;
  3. vérifie les **garde-fous** (deadline, motif obligatoire, preuve…) ;
  4. écrit une ligne dans `order_status_history` (from, to, actor, reason) ;
  5. s'exécute dans une **transaction DB** (avec toute écriture financière) ;
  6. déclenche les **événements** (OrderAccepted, OrderReady, OrderDelivered…) pour notifications/jobs (J33).
- Rollback : si une étape échoue → transaction annulée, aucun statut partiel.

## 5. Garde-fous par transition

| Transition | Garde-fou |
|-----------|-----------|
| T2 | Panier mono-vendeur OK ; stock réservé ; zone/tarif valide ; montants calculés |
| T3 | Webhook vérifié (J16) ; montant == total_client ; idempotence ; commande en `awaiting_payment` |
| T5 | Deadline atteinte → `cancelled` (motif `expiration_paiement`), stock libéré |
| T6 | Dans le délai de réponse vendeur ; sinon timeout/incident |
| T7 | Motif obligatoire ; pas si `assigned`+ |
| T8 | Dans la rétraction client ; sinon selon J12 |
| T11 | Livreur `active`+`online` ; une course = une commande |
| T14 | Preuve de livraison saisie valide |
| T15 | Conforme matrice J12 (acteur × statut) |
| T16 | Refund demandé + exécuté (Kkiapay) ; écriture journal |

## 6. Deadlines configurables (config/beninfood)

```
orders.payment_deadline_minutes = 15
orders.vendor_acceptance_minutes = 5   (à valider)
orders.client_withdrawal_minutes = X
orders.driver_offer_seconds = 60
orders.driver_acceptance_seconds = 45
```

> Référence : config par la porteuse (J23 §Paramètres). Sur expirations → jobs schedulés (J33).

## 7. Mapping statuts commande → action utilisateur (UI)

| Statut | Client voit | Vendeur voit | Livreur voit |
|--------|-------------|--------------|--------------|
| draft | brouillon | — | — |
| awaiting_payment | payer (lien Kkiapay) | — | — |
| paid | en cours | Accepter / Refuser (motif) | — |
| accepted | préparé ✓ | Démarrer préparation | — |
| preparing | en préparation | Marquer prête | — |
| ready | prête | — | En attente d'affectation |
| assigned | un livreur arrive | — | Accepter / collecter |
| picked_up | en route | — | Commencer livraison |
| in_delivery | en route vers vous | — | Marquer livrée (+preuve) |
| delivered | livrée (avis) | terminée | terminée |
| cancelled | (motif) | (motif) | — |
| refunded | remboursée | (info) | — |

## 8. Critères d'acceptation

- [ ] State machine codée et testée unitairement (toutes transitions T1-T16)
- [ ] Transitions interdites = testées en négatif (403/422)
- [ ] `order_status_history` alimenté à chaque transition avec auteur + motif
- [ ] Deadlines configurables via config
- [ ] Événements émis par transition (J33)