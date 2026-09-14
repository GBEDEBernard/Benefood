# J11 — Cycle de vie de la commande

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Validé — **Source :** Plan directeur V1.2, Phase 02, J11

---

## 1. Objet

Définir la **machine à états** de la commande et les transitions autorisées. Chaque transition est horodatée, auditée et notifiée.

## 2. Rappel de la règle du panier

**Un seul vendeur par commande.** Le panier est découpé par vendeur : si un client souhaite des produits de plusieurs vendeurs, il crée plusieurs commandes (une par vendeur). (Décision validée le 14/09/2026.)

## 3. Liste des statuts

| # | Statut | Code | Description |
|---|--------|------|-------------|
| 1 | Brouillon | `draft` | Commande en cours de construction côté client (créée depuis le panier) |
| 2 | En attente de paiement | `awaiting_payment` | Commande figée, en attente du paiement du client |
| 3 | Payée | `paid` | Paiement confirmé par webhook (voir J16) |
| 4 | Acceptée | `accepted` | Vendeur a accepté la commande |
| 5 | En préparation | `preparing` | Vendeur prépare les articles |
| 6 | Prête | `ready` | Articles préparés, en attente de collecte/affectation livreur |
| 7 | Affectée | `assigned` | Un livreur est assigné à la course |
| 8 | Prise en charge | `picked_up` | Le livreur a récupéré la commande chez le vendeur |
| 9 | En livraison | `in_delivery` | Le livreur est en route vers le client |
| 10 | Livrée | `delivered` | Livraison confirmée (+ preuve) |
| 11 | Annulée | `cancelled` | Commande annulée (voir J12) |
| 12 | Remboursée | `refunded` | Remboursement effectué après annulation (si dû) |

> **Note :** dans le cadre d'une commande « à retirer » (par exemple click & collect) si retenue, la branche livraison peut être sautée. Le périmètre V1.2 retient la **livraison** comme flux principal ; le retrait en boutique est laissé en option (boutique fermée → pas de commande).

## 4. Machine à états complète

```
                        ┌────────────────────────────────────────────┐
                        │                                            │
draft ──▶ awaiting_payment ──▶ paid ──▶ accepted ──▶ preparing ──▶ ready
              │                │  │         │             │           │
              │                │  │         └──▶ cancelled            │
              │                │  └──▶ cancelled                      │
              v                v                                       │
     cancelled (expiration)  cancelled (client)                        │
                                                                       v
        refunded ◀─ cancelled ◀── (contexte annulation)         assigned
              ▲                    │                             │
              │                    ▼                             │
              │              (règles J12)                        ▼
              └────────────────────────────────────────────── picked_up
                                                                    │
                                                                    ▼
                                                               in_delivery
                                                                    │
                                                                    ▼
                                                               delivered
```

### 4.1 Transitions autorisées

| De | Vers | Déclencheur | Acteur |
|----|------|-------------|--------|
| — | `draft` | Création depuis le panier (panier validé mono-vendeur) | Client |
| `draft` | `awaiting_payment` | Confirmation du récapitulatif + choix de paiement | Client |
| `awaiting_payment` | `paid` | Confirmation de paiement (webhook Kkiapay vérifié) | Système |
| `awaiting_payment` | `cancelled` | Abandon par le client avant paiement | Client |
| `awaiting_payment` | `cancelled` | Expiration du délai de paiement (durée configurable) | Système |
| `paid` | `accepted` | Acceptation par le vendeur | Vendeur |
| `paid` | `cancelled` | Refus du vendeur (voir J12) | Vendeur |
| `paid` | `cancelled` | Annulation par le client (limite : avant acceptation, sans frais) | Client |
| `accepted` | `preparing` | Début de préparation | Vendeur |
| `preparing` | `ready` | Préparation terminée | Vendeur |
| `ready` | `assigned` | Affectation d'un livreur (règles Phase 13) | Système / Porteuse |
| `assigned` | `picked_up` | Collecte chez le vendeur | Livreur |
| `picked_up` | `in_delivery` | Départ vers le client | Livreur |
| `in_delivery` | `delivered` | Confirmation de livraison + preuve | Livreur / Client |
| (contexte) | `cancelled` | Annulation selon les règles J12 | selon J12 |
| `cancelled` | `refunded` | Remboursement exécuté (si dû) | Système |

### 4.2 Règles générales

1. **Une seule transition « sens »** : une commande est linéaire ; il n'y a **pas de retour en arrière** dans la machine (draft → refunded, jamais refunded → paid).
2. Le **statut courant** est dérivé de l'historique ; le dernier événement fait foi.
3. Chaque transition est enregistrée dans `order_status_history` : statut précédent, nouveau statut, auteur, date, motif le cas échéant.
4. Toute transition avec impact **financier** (paiement, remboursement, annulation) déclenche la création d'**écritures** dans le journal financier (J14).
5. Le **montant total client** est calculé côté serveur et ne change plus après `awaiting_payment` sauf cas d'exception validé (J14).

## 5. Comportements par statut

### 5.1 `draft`
- Le panier est mis en ordre (mono-vendeur).
- Le client peut encore modifier quantités / supprimer des articles.
- Le sous-total, la livraison et le total sont calculés côté serveur (quote) sans être figés.

### 5.2 `awaiting_payment`
- **Snapshot des articles figé** : nom, prix unitaire, quantité, sous-total sont gelés dans `order_items` (J66/J84).
- Le total est figé.
- Un **deadline de paiement** démarre (durée configurable, ex. 15 minutes).
- Si le délai expire : la commande passe `cancelled` (motif `expiration_paiement`) et les stocks réservés sont libérés.

### 5.3 `paid`
- Le paiement est **confirmé par webhook vérifié** (J16) — jamais par la seule déclaration du mobile.
- La commande devient éligible à l'acceptation par le vendeur.
- Le vendeur est notifié (push prioritaire).

### 5.4 `accepted` / `preparing` / `ready`
- Le vendeur a l'exclusivité de ces transitions.
- Si le vendeur ne répond pas dans le délai (configurable) : options possibles = rappel, puis incident, puis annulation/remboursement selon J12.

### 5.5 `assigned` / `picked_up` / `in_delivery` / `delivered`
- Le livreur a l'exclusivité de ces transitions.
- `assigned` → `picked_up` requiert une **preuve de collecte** (optionnel, horodatage minimum).
- `delivered` requiert une **preuve de livraison** (code de confirmation / photo / signature selon la règle retenue en Phase 13).

## 6. Statuts d'exception (annulation / remboursement)

Voir le document J12 pour :
- les acteurs autorisés, les délais, les motifs obligatoires ;
- quand un remboursement est dû, total ou partiel ;
- les conséquences financières (retour/liquidation de la commission, etc.) ;
- les notifications.

## 7. Critères d'acceptation

- [ ] Les 12 statuts et toutes les transitions du tableau 4.1 sont implémentées
- [ ] Aucune transition non autorisée n'est possible (policy serveur)
- [ ] Chaque transition est historisée (`order_status_history`) et notifiée
- [ ] Le snapshot des articles est figé au passage `awaiting_payment`
- [ ] Les délais (paiement, acceptation) sont configurables
- [ ] Les statuts financiers (paid, cancelled, refunded) sont combinés au journal financier (J14)
- [ ] Commande E2E de bout en bout testée (draft → delivered)