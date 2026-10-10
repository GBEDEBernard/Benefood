# Audit d'écart — Cahier de conception v1.0 (oct. 2026) ↔ Code

Document de travail. Comparaison du *Cahier de conception : pages de chaque
acteur, flux de paiement, wallets et commissions* (v1.0, octobre 2026) avec
l'état réel du backend Laravel et de l'app Flutter.

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
| **FedaPay** retenue comme passerelle | Implémenté avec **Kkiapay** (`backend/app/Services/Payments/KkiapayConnector.php`, `config/kkiapay.php`, webhook `POST /api/v1/payments/webhook`) | 🟡 divergence de prestataire |
| Abstraction `PaymentGateway` | ✅ présente (`PaymentGateway.php`) — réversibilité possible | ✅ |
| Webhook vérifié côté serveur + idempotence | ✅ signature HMAC + `payment_events` (déduplication) | ✅ |
| Frais FedaPay 1,2 % | ❌ `order_financials.payment_fee = 0` en dur, jamais calculé | ❌ |

> Le passage à FedaPay n'est qu'un nouvel adapter `PaymentGateway` : le
> reste du code ne dépend pas du prestataire.

## 2. Commissions & frais

| Règle du cahier | État code | Verdict |
|---|---|---|
| Vendeur 10 % sur la nourriture | ✅ configurable (`commission_rates`), exception vendeur, figé par commande (`OrderService::resolveCommissionRate`, `order_financials`) | ✅ |
| Livreur 20 % sur la livraison | ❌ `delivery_partner_amount` toujours `0` (`OrderService::createFromCart` L182) | ❌ |
| Client 5 % de frais de service | ❌ jamais calculé — `total = subtotal + delivery_fee` ; `payment_fee = 0` | ❌ |
| Montants/commissions calculés serveur, figés | ✅ snapshot `order_financials` + `delivery_rate_snapshot` | ✅ |
| Grille de livraison 500 / 1 000 / 2 000 F selon distance | 🟡 `delivery_rates` = **prix fixe par zone**, pas de paliers par distance (pas de tranche 500/1 000/2 000) | 🟡 |

## 3. Le parcours de l'argent (séquestre → wallets)

| Étape du cahier | État code | Verdict |
|---|---|---|
| Client paie vers le compte plateforme | ✅ (Kkiapay) | ✅ |
| Confirmation webhook → statut `paid` | ✅ `PaymentController::webhook`, `OrderService::confirmPayment` | ✅ |
| **Répartition système** : wallet vendeur + wallet livreur + plateforme | ❌ aucune écriture wallet à la confirmation ni à la livraison | ❌ |
| **Séquestre** : crédité « en attente », libéré après livraison | ❌ `Wallet` n'a qu'un seul champ `balance` (pas de `pending_balance` / `available_balance`) | ❌ |
| Journal comptable immuable (ledger) | 🟡 table `financial_journal` + `FinancialJournalService`, mais écrit **uniquement** sur contre-passée d'annulation — pas au paiement ni à la livraison | 🟡 |
| Argent réel reste chez la passerelle jusqu'au retrait | ✅ conforme par construction (rien n'est décaissé) | ✅ |

> **C'est le principal trou fonctionnel** : aujourd'hui une commande payée puis
> livrée ne crédite **aucun** wallet et ne laisse qu'une seule écriture
> comptable éventuelle. La « règle d'or » (répartition interne) n'est pas
> encore codée.

## 4. Wallets & retraits

| Point du cahier | État code | Verdict |
|---|---|---|
| Wallet interne vendeur / livreur | 🟡 modèles + tables existent (`wallets`, `payouts`, `wallet_transactions`) mais **aucune écriture** produite | ❌ (inutilisé) |
| Solde en attente / solde disponible | ❌ un seul solde | ❌ |
| Retrait (montant + numéro MM), minimum de retrait | ❌ aucune route/service de demande de retrait (API ou back-office) | ❌ |
| Mode A (à la demande) / Mode B (paiement groupé) | ❌ non implémenté | ❌ |
| Journal des mouvements de wallet | ❌ modèle `WalletTransaction` absent (table + enum `WalletTransactionType` existent, jamais utilisés) | ❌ |
| Payouts visibles vendeur | 🟡 lecture seule (`VendorRevenueService`, écran revenus) — pas de création/exécution | 🟡 |
| **Paiement à la livraison (cash)** + wallet livreur prépayé | ❌ mentionné côté UI comme libellé (`order_details_screen.dart:325`) mais aucun flux : pas de choix de paiement, pas de vérification de solde, pas de débit commissions | ❌ |
| Blocage si solde livreur négatif | ❌ absent | ❌ |

## 5. Pages par acteur

### 5.1 Client
| Page du cahier | État | Verdict |
|---|---|---|
| Inscription/connexion tél. + code SMS | ✅ OTP (`/auth/send-phone-code`, `/auth/verify-phone`) | ✅ |
| Accueil (catégories, proches, recherche, promos) | ✅ | ✅ |
| Page vendeur / détail plat / panier | ✅ | ✅ |
| Panier avec frais de service 5 % | ❌ le récap n'affiche pas de frais de service (non calculés) | ❌ |
| Paiement Mobile Money / à la livraison | 🟡 Mobile Money ✅ ; **à la livraison ❌** | 🟡 |
| Suivi de commande en direct + contact livreur | ✅ | ✅ |
| **Envoyer un colis** (A→B, tarif distance) | ❌ service inexistant | ❌ |
| Historique & reçus / recommander | ✅ | ✅ |
| **Avis** vendeur **et livreur** | 🟡 vendeur : consultation ✅, **dépôt d'avis client ❌** (aucune route) ; **avis livreur ❌** | ❌ |
| Litiges / signaler un problème | ✅ réclamations (`complaints`) | ✅ |
| Profil (adresses, paiement, notifications) | ✅ | ✅ |

### 5.2 Vendeur
Dashboard, produits, commandes entrantes (accepter/refuser/prête), wallet/revenus,
stats, paramètres boutique → ✅ présents (`features/vendor/...`, `vendors/me/*`).
Walllet = lecture seule (cf. §4).

### 5.3 Livreur
| Page du cahier | État | Verdict |
|---|---|---|
| Inscription & validation | ✅ | ✅ |
| Disponibilité en ligne/hors ligne | ✅ | ✅ |
| Courses proposées (gain net après commission) | 🟡 liste ✅ mais **gain net/commission ❌** (pas calculés) | 🟡 |
| Course en cours (statuts, appel) | ✅ | ✅ |
| Confirmation : code de livraison / photo | ✅ `deliveries.proof_code`, `proof_photo_path` | ✅ |
| **Wallet livreur** (en attente/dispo, prépayé, retirer) | ❌ aucune page, aucun endpoint | ❌ |
| Historique & gains | 🟡 historique ✅ ; gains par jour/semaine ❌ | 🟡 |

### 5.4 Back-office administrateur
| Page du cahier | État | Verdict |
|---|---|---|
| Dashboard KPI | ✅ | ✅ |
| Validation comptes vendeurs/livreurs | ✅ | ✅ |
| Commandes + intervention | ✅ (+ annulation admin) | ✅ |
| Paiements & transactions | ✅ (`admin/payments`) | ✅ |
| Commissions & frais (édition taux) | ✅ | ✅ |
| **Wallets & retraits** (soldes, retraits, lots) | ❌ aucun écran | ❌ |
| Litiges & remboursements | ✅ | ✅ |
| Utilisateurs (clients/vendeurs/livreurs) | ✅ | ✅ |
| Catalogue, zones & tarifs | ✅ | ✅ |
| Rapports exports | 🟡 CSV/Excel ✅ ; **PDF ❌** | 🟡 |
| Rôles & journal d'audit | ✅ rôles + `admin/audit` | ✅ |

## 6. Statuts d'une commande

| Statut cahier | Enum code | Verdict |
|---|---|---|
| En attente de paiement / Payée / Acceptée / En préparation / Prête / En livraison / Livrée / Annulée | ✅ (`OrderStatus`) + `assigned`, `picked_up` en plus | ✅ |
| **En litige** (solde bloqué) | 🟡 pas de statut commande dédié — géré via `complaints` séparés, sans blocage de solde (car wallets non implémentés) | 🟡 |
| Confirmation livraison par code client + délai auto 30 min | 🟡 code livraison ✅ ; **auto-confirmation 30 min ❌** | 🟡 |
| Annulation auto si non payée (15 min) | ✅ `orders:expire-payments` (planifié chaque minute) | ✅ |

## 7. Sécurité

| Règle du cahier | État | Verdict |
|---|---|---|
| Ne jamais croire l'écran client, seul le webhook valide | ✅ | ✅ |
| Montants/commissions calculés serveur | ✅ | ✅ |
| Écriture comptable immuable | ✅ append-only (mais alimentée seulement sur annulation) | 🟡 |
| Code de livraison | ✅ | ✅ |
| Validation manuelle vendeurs/livreurs | ✅ | ✅ |
| Double authentification admin | ❌ non implémenté | ❌ |
| Sauvegardes régulières | ➖ hors code (ops) | — |

## 8. Plan par phases

| Phase cahier | État | Verdict |
|---|---|---|
| 1 — Base (comptes, produits, commandes, paiement, wallets, back-office minimal) | 🟡 tout sauf **wallets** et **frais 5 %** | 🟡 |
| 2 — Livraison (app livreur, attribution, code, cash + wallet prépayé) | 🟡 app livreur + code ✅ ; **cash + wallet prépayé ❌** | 🟡 |
| 3 — Colis | ❌ | ❌ |
| 4 — Croissance (promos, notes, rapports, retraits groupés, Kkiapay) | 🟡 promos/notes partiels ; retraits groupés ❌ | 🟡 |

---

## Synthèse — écarts prioritaires

**Blocants métier (règle d'or non codée)**
1. **Répartition automatique vers les wallets** à la confirmation/livraison + **journal** systématique.
2. **Frais de service client 5 %** et **commission livreur 20 %** dans `order_financials` / total.
3. **Séquestre** : scinder wallet en `pending` / `available`, libération après livraison.
4. **Retraits (payouts)** : demande vendeur/livreur, minimum, exécution back-office, plus tard par lot.

**Fonctions absentes**
5. **Service colis** (A→B, tarif par distance 500/1 000/2 000 F).
6. **Paiement à la livraison (cash)** + wallet livreur prépayé + blocage si solde négatif.
7. **Dépôt d'avis client** (vendeur + livreur).
8. **Wallet livreur** (mobile + back-office) et écran admin « wallets & retraits ».

**Décisions à trancher**
9. **FedaPay vs Kkiapay** : le cahier retient FedaPay, le code est en Kkiapay.
10. **2FA admin**, exports PDF, auto-confirmation livraison 30 min.
11. **Statut « en litige »** de commande (blocage de solde) — aujourd'hui via réclamations.

> Les **taux ne sont pas une décision** : ils sont fixés par le cahier (§0).
> Seul taux à confirmer hors document : les **1,2 % FedaPay** (voir §0),
> d'après les tarifs officiels FedaPay — à figer dans le contrat marchand.
