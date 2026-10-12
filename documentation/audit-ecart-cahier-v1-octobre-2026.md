# Audit d'écart — Cahier de conception v1.0 (oct. 2026) ↔ Code

Document de travail. Comparaison du *Cahier de conception : pages de chaque
acteur, flux de paiement, wallets et commissions* (v1.0, octobre 2026) avec
l'état réel du backend Laravel et de l'app Flutter.

> **Mise à jour du 12 octobre 2026** : document réconcilié après
> l'implémentation des wallets/séquestre, des retraits (modes A et B), du
> service colis, des avis client, du paiement cash + flottant livreur, de
> l'auto-confirmation des livraisons et de la 2FA back-office. Les écarts
> restants sont signalés explicitement.

Légende : ✅ conforme · 🟡 partiel / divergent · ❌ absent

---

## 0. Barème officiel (fixé par le cahier — extrait du PDF)

Taux **imposés par le document**, aucun arbitrage à faire :

| Qui | Taux | Base de calcul |
|---|---|---|
| Vendeur | **10 %** | prix de la nourriture |
| Livreur | **20 %** | prix de la livraison |
| Client (frais de service) | **5 %** | nourriture + livraison |
| FedaPay (coût plateforme) | **1,2 %** | montant payé par le client |

> ⚠️ Le cahier de conception indiquait **1,8 %** ; ce taux est **corrigé à
> 1,2 %** d'après la lecture des tarifs officiels FedaPay (à confirmer une
> dernière fois sur le contrat/tableau de bord marchand).

Simulation officielle (montants en F CFA) :

| | Petite | Moyenne | Grosse |
|---|---|---|---|
| Nourriture | 1 000 | 5 000 | 20 000 |
| Livraison | 500 | 1 000 | 1 000 |
| Frais service client (5 %) | 75 | 300 | 1 050 |
| **Le client paie** | 1 575 | 6 300 | 22 050 |
| Vendeur reçoit (90 %) | 900 | 4 500 | 18 000 |
| Livreur reçoit (80 %) | 400 | 800 | 800 |
| Revenus plateforme | 275 | 1 000 | 3 250 |
| Frais FedaPay (1,2 %) | 19 | 76 | 265 |
| Gain net plateforme | 256 | 924 | 2 985 |

Autres paramètres fixés : **retrait minimum ≈ 1 000 F** (exemple), solde wallet scindé
**en attente** (non retirable) / **disponible** (retirable), retrait **par lots**
(recommandé : mode B, quotidien/hebdo), colis : livreur **80 %** / plateforme **20 %**.

---

## 1. Passerelle de paiement

| Point du cahier | État code | Verdict |
|---|---|---|
| **FedaPay** retenue comme passerelle | Implémenté avec **Kkiapay** (`backend/app/Services/Payments/KkiapayConnector.php`, `config/kkiapay.php`, webhook `POST /api/v1/payments/webhook`) | 🟡 divergence de prestataire (décision en attente) |
| Abstraction `PaymentGateway` | ✅ présente (`PaymentGateway.php`) — réversibilité possible | ✅ |
| Webhook vérifié côté serveur + idempotence | ✅ signature HMAC + `payment_events` (déduplication) | ✅ |
| Frais FedaPay 1,2 % | ✅ calculé (`FinanceService::breakdown`, `payment_gateway.fee_rate_basis_points`) et figé dans `order_financials.payment_fee` | ✅ |

> Le passage à FedaPay n'est qu'un nouvel adapter `PaymentGateway` : le
> reste du code ne dépend pas du prestataire. Décision à trancher.

## 2. Commissions & frais

| Règle du cahier | État code | Verdict |
|---|---|---|
| Vendeur 10 % sur la nourriture | ✅ configurable (`commission_rates`), exception vendeur, figé par commande (`OrderService::resolveCommissionRate`, `order_financials`) | ✅ |
| Livreur 20 % sur la livraison | ✅ calculée et figée (`FinanceService::breakdown`, `order_financials.delivery_partner_amount`), créditée au livreur à l'assignation | ✅ |
| Client 5 % de frais de service | ✅ calculé (`FinanceService::breakdown`), inclus dans le total et affiché au récapitulatif mobile | ✅ |
| Montants/commissions calculés serveur, figés | ✅ snapshot `order_financials` + `delivery_rate_snapshot` | ✅ |
| Grille de livraison 500 / 1 000 / 2 000 F selon distance | 🟡 livraison nourriture = **prix fixe par zone** (`delivery_rates`) ; **colis** appliquent des paliers par distance 500/1 000/2 000 F (`beninfood.parcels.tiers`) | 🟡 |

## 3. Le parcours de l'argent (séquestre → wallets)

| Étape du cahier | État code | Verdict |
|---|---|---|
| Client paie vers le compte plateforme | ✅ (Kkiapay) | ✅ |
| Confirmation webhook → statut `paid` | ✅ `PaymentController::webhook` délègue à `OrderService::confirmPayment` | ✅ |
| **Répartition système** : wallet vendeur + wallet livreur + plateforme | ✅ `FinanceService::distributeOrderPayment` (part vendeur en attente) + `creditDriverForDelivery` (à l'assignation) ; plateforme journalisée | ✅ |
| **Séquestre** : crédité « en attente », libéré après livraison | ✅ `Wallet.pending_balance` / `available_balance`, `FinanceService::releasePending` appelé à la livraison | ✅ |
| Journal comptable immuable (ledger) | ✅ `financial_journal` (append-only) : vente + commission au paiement, **transfert** vendeur/livreur à la livraison, contre-passée à l'annulation | ✅ |
| Argent réel reste chez la passerelle jusqu'au retrait | ✅ conforme par construction (rien n'est décaissé) | ✅ |

## 4. Wallets & retraits

| Point du cahier | État code | Verdict |
|---|---|---|
| Wallet interne vendeur / livreur | ✅ `wallets`, `wallet_transactions` alimentés par `FinanceService` | ✅ |
| Solde en attente / solde disponible | ✅ `pending_balance` / `available_balance` (migration escrow) | ✅ |
| Retrait (montant + numéro MM), minimum de retrait | ✅ `WalletController::requestVendorPayout` / `requestDriverPayout`, `PayoutService::request` (contrôle `wallet.min_payout`) | ✅ |
| Mode A (à la demande) / Mode B (paiement groupé) | ✅ Mode A (API) ; Mode B (`PayoutService::createBatch`/`executeBatch`, écrans back-office) | ✅ |
| Journal des mouvements de wallet | ✅ `WalletTransaction` alimenté à chaque opération (`FinanceService::writeTransaction`) | ✅ |
| Payouts visibles vendeur | ✅ liste + demande + suivi (`VendorRevenueService`, écran revenus) | ✅ |
| **Paiement à la livraison (cash)** + wallet livreur prépayé | ✅ backend : `PaymentMethod::Cash`, `CashService` (`topUp`, `settle`), `DriverFloatController`, solde `driver_profiles.prepaid_balance` | ✅ |
| Blocage si solde livreur négatif | ✅ `OrderService::assignDriver` et `CashService::settle` refusent si la couverture est insuffisante (`cash.insufficient_float`, 409) | ✅ |

> Le choix « paiement à la livraison » n'est pas encore exposé dans le tunnel
> d'achat mobile : le backend le supporte (`payment_method`), l'UI crée
> aujourd'hui des commandes en ligne.

## 5. Pages par acteur

### 5.1 Client
| Page du cahier | État | Verdict |
|---|---|---|
| Inscription/connexion tél. + code SMS | ✅ OTP (`/auth/send-phone-code`, `/auth/verify-phone`) | ✅ |
| Accueil (catégories, proches, recherche, promos) | ✅ | ✅ |
| Page vendeur / détail plat / panier | ✅ | ✅ |
| Panier avec frais de service 5 % | ✅ calculés serveur + affichés au récapitulatif mobile | ✅ |
| Paiement Mobile Money / à la livraison | 🟡 Mobile Money ✅ ; **cash backend ✅ mais non proposé dans le tunnel mobile** | 🟡 |
| Suivi de commande en direct + contact livreur | ✅ | ✅ |
| **Envoyer un colis** (A→B, tarif distance) | ✅ client (`/parcels/*`) + livreur (onglet Colis) | ✅ |
| Historique & reçus / recommander | ✅ | ✅ |
| **Avis** vendeur **et livreur** | ✅ dépôt client (`POST /orders/{id}/review`) avec note vendeur + note livreur, bouton mobile | ✅ |
| Litiges / signaler un problème | ✅ réclamations (`complaints`) | ✅ |
| Profil (adresses, paiement, notifications) | ✅ | ✅ |

### 5.2 Vendeur
Dashboard, produits, commandes entrantes (accepter/refuser/prête), wallet/revenus,
stats, paramètres boutique → ✅ présents (`features/vendor/...`, `vendors/me/*`).
Wallet désormais alimenté (séquestre → disponible) et retrait possible (§4).

### 5.3 Livreur
| Page du cahier | État | Verdict |
|---|---|---|
| Inscription & validation | ✅ | ✅ |
| Disponibilité en ligne/hors ligne | ✅ | ✅ |
| Courses proposées (gain net après commission) | ✅ gain net / part livreur calculés (`delivery_partner_amount`) | ✅ |
| Course en cours (statuts, appel) | ✅ | ✅ |
| Confirmation : code de livraison / photo | ✅ `deliveries.proof_code`, `proof_photo_path` | ✅ |
| **Wallet livreur** (en attente/dispo, prépayé, retirer) | ✅ écran wallet (solde disponible + flottant prépayé) + retrait | ✅ |
| Historique & gains | 🟡 historique ✅ ; gains par jour/semaine toujours partiels | 🟡 |

### 5.4 Back-office administrateur
| Page du cahier | État | Verdict |
|---|---|---|
| Dashboard KPI | ✅ | ✅ |
| Validation comptes vendeurs/livreurs | ✅ | ✅ |
| Commandes + intervention | ✅ (+ annulation admin) | ✅ |
| Paiements & transactions | ✅ (`admin/payments`) | ✅ |
| Commissions & frais (édition taux) | ✅ | ✅ |
| **Wallets & retraits** (soldes, retraits, lots) | ✅ écrans back-office (`admin/payouts`, `admin/payouts/batches`) | ✅ |
| Litiges & remboursements | ✅ | ✅ |
| Utilisateurs (clients/vendeurs/livreurs) | ✅ | ✅ |
| Catalogue, zones & tarifs | ✅ | ✅ |
| Rapports exports | 🟡 CSV/Excel ✅ ; **PDF ❌** | 🟡 |
| Rôles & journal d'audit | ✅ rôles + `admin/audit` | ✅ |

## 6. Statuts d'une commande

| Statut cahier | Enum code | Verdict |
|---|---|---|
| En attente de paiement / Payée / Acceptée / En préparation / Prête / En livraison / Livrée / Annulée | ✅ (`OrderStatus`) + `assigned`, `picked_up` en plus | ✅ |
| **En litige** (solde bloqué) | 🟡 pas de statut commande dédié — géré via `complaints` séparés | 🟡 |
| Confirmation livraison par code client + délai auto 30 min | ✅ code livraison + auto-confirmation (`orders:auto-confirm-deliveries`) qui libère le séquestre | ✅ |
| Annulation auto si non payée (15 min) | ✅ `orders:expire-payments` (planifié chaque minute) | ✅ |

## 7. Sécurité

| Règle du cahier | État | Verdict |
|---|---|---|
| Ne jamais croire l'écran client, seul le webhook valide | ✅ | ✅ |
| Montants/commissions calculés serveur | ✅ | ✅ |
| Écriture comptable immuable | ✅ append-only : vente, commission, transfert (livraison), contre-passée (annulation) | ✅ |
| Code de livraison | ✅ | ✅ |
| Validation manuelle vendeurs/livreurs | ✅ | ✅ |
| Double authentification admin | ✅ défi signé + code OTP à la connexion back-office (`POST /auth/login/two-factor`) | ✅ |
| Sauvegardes régulières | ➖ hors code (ops) | — |

## 8. Plan par phases

| Phase cahier | État | Verdict |
|---|---|---|
| 1 — Base (comptes, produits, commandes, paiement, wallets, back-office minimal) | ✅ comptes, produits, commandes, paiement, wallets (séquestre) et frais 5 % | ✅ |
| 2 — Livraison (app livreur, attribution, code, cash + wallet prépayé) | ✅ app livreur, code, cash + wallet prépayé, blocage flottant | ✅ |
| 3 — Colis | ✅ service colis A→B (client + livreur, tarif par distance) | ✅ |
| 4 — Croissance (promos, notes, rapports, retraits groupés, Kkiapay) | 🟡 promos/notes partiels ; retraits groupés ✅ ; rapports PDF ❌ ; Kkiapay (vs FedaPay) | 🟡 |

---

## Synthèse — écarts prioritaires

**Blocants métier (règle d'or)** — ✅ traités
1. Répartition automatique vers les wallets à la confirmation/livraison + journal.
2. Frais de service client 5 % et commission livreur 20 % dans `order_financials`.
3. Séquestre scindé `pending` / `available`, libération après livraison.
4. Retraits (payouts) : demande vendeur/livreur, minimum, exécution back-office, lots.

**Fonctions absentes** — ✅ traitées
5. Service colis (A→B, tarif par distance 500/1 000/2 000 F).
6. Paiement à la livraison (cash) + wallet livreur prépayé + blocage si solde négatif.
7. Dépôt d'avis client (vendeur + livreur).
8. Wallet livreur (mobile + back-office) et écran admin « wallets & retraits ».

**Écarts restants**
9. **Choix de la passerelle** : FedaPay (cahier) vs Kkiapay (code).
10. **Tunnel de paiement mobile** : option « à la livraison » non exposée côté client (backend prêt).
11. **Exports PDF** des rapports admin.
12. **Statut « en litige »** de commande (blocage de solde) — aujourd'hui via réclamations.
13. **Grille de livraison par distance** pour la nourriture (aujourd'hui prix fixe par zone).
14. **Gains livreur par jour/semaine** encore partiels.

> Les **taux ne sont pas une décision** : ils sont fixés par le cahier (§0).
> Seul taux à confirmer hors document : les **1,2 % FedaPay** (voir §0),
> d'après les tarifs officiels FedaPay — à figer dans le contrat marchand.
