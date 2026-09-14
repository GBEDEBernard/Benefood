# J18 — Règles métier consolidées

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** ✔ Document de référence de la Phase 02 — **Source :** J08-J17

> Ce document consolide et fait référence aux règles métier de la Phase 02. Il est le document de référence avant le développement des modules financiers et la poursuite des phases. Toute modification doit passer par un changement versionné de ce document.

---

## A. Décisions fondatrices

| # | Décision | Valeur |
|---|----------|--------|
| D1 | Architecture mobile | **1 app Flutter multi-rôles** (Client/Vendeur/Livreur) |
| D2 | Backend | Laravel API `/api/v1` (source de vérité métier/financière/security) |
| D3 | Rôles cumulables | **Oui** ; contexte actif ≠ autorisation (RBAC serveur) |
| D4 | Prestataire paiement | **Kkiapay** (réversible via `PaymentGateway`) |
| D5 | Panier | **Un seul vendeur par commande** |
| D6 | Accès porteuse | **Back-office uniquement, jamais d'accès direct DB** |

---

## B. Acteurs (J08)

| Acteur | Expérience | Rôle principal |
|--------|-----------|----------------|
| Porteuse (A1) | Back-office | Pilotage métier, validation, commissions, zones, litiges |
| Admin technique (A2) | Back-office | Technique, accès, logs, support L2 |
| Vendeur (A3) | App (mode Vendeur) | Boutique, catalogue, commandes, revenus |
| Client (A4) | App (mode Client) | Commande, paiement, suivi, réclamation |
| Livreur indép. (A5) | App (mode Livreur) | Courses, livraison, gains |
| Livreur Béninfood (A6) | App (mode Livreur) | Courses (salarié) |

---

## C. Cycles de vie

### C.1 Vendeur (J09)
`registered → pending_verification → verified → active` (+ `suspended`, `closed`). Seul un vendeur `active` vend. Statut compte ≠ statut boutique.

### C.2 Livreur (J10)
`candidate → pending_validation → validated → active` (+ `suspended`, `closed`). Disponibilité `online/offline` séparée du compte. Une course = un livreur.

### C.3 Commande (J11)
Statuts : `draft → awaiting_payment → paid → accepted → preparing → ready → assigned → picked_up → in_delivery → delivered`, avec `cancelled` / `refunded` en états exceptionnels. Transitions linéaires, historisées, auditables.

---

## D. Règles financières

### D.1 Commission (J13)
- Taux global configurable par la porteuse, type **10 % (référence)**.
- Base = sous-total éligible (après remise) ; frais de livraison/paiement exclus.
- **Snapshot par commande** : taux + montant figés dans `order_financials`.
- Exceptions par vendeur possibles (taux personnalisé, prime sur le global).
- Arrondis en centimes, demi-up.

### D.2 Répartition (J14)
- `total_client = subtotal + delivery_fee + payment_fee - discount`
- `part_vendeur = base - commission`
- `commission_béninfood = base × taux`
- `delivery_fee` → part livreur (indépendant : ≈100 % par défaut) ; livreur Béninfood rémunéré par Béninfood.
- Journal financier **immuable** ; contre-passées sur annulation ; wallets vendeur + reversements tracés.

### D.3 Paiement (J16)
- Initiation serveur → lien/flow ; confirmation par **webhook vérifié** seulement.
- **Montant toujours recalculé côté serveur** (J94) ; idempotence des webhooks ; gestion échec/expiration/doublon/webhook tardif ; remboursements tracés ; rapprochement (J105).

### D.4 Annulations / remboursements (J12)
- Motif obligatoire ; acteurs selon statut (voir matrice J12).
- Remboursement déterminé automatiquement (total / partiel / nul) selon avancement.
- Contre-passée commission/parts ; notifications toutes parties.

---

## E. Livraison par zones (J15)

- Zones définies + administrées par la porteuse (back-office).
- Sélection auto de la zone depuis l'adresse client ; tarif (global ou spécifique vendeur) **figé** sur la commande.
- Blocage propre si zone inconnue / inactive / non desservie par le vendeur.

---

## F. Règles transversales de sécurité

1. RBAC + policies ; le contexte mobile n'est jamais une autorisation.
2. Aucune clé (Kkiapay, Firebase) dans Flutter/Git/réponses API.
3. Montants sensibles calculés uniquement côté Laravel.
4. Actions sensibles auditées ; porteuse sans accès direct DB.

---

## G. Champs de validation restants à verrouiller (par la porteuse)

| Élément | Valeur proposée | État |
|---------|-----------------|------|
| Taux de commission initial | 10 % | ☐ À valider |
| Frais de préparation sur annulation | à définir | ☐ |
| Frais d'annulation après affectation | à définir | ☐ |
| Durée de rétraction client (après paiement) | à définir | ☐ |
| Deadline de paiement | 15 min | ☐ |
| Délai de réponse vendeur (acceptation) | à définir | ☐ |
| Part du livreur indépendant sur delivery_fee | 100 % | ☐ |
| Frais de paiement agrégateur : à la charge de | Béninfood (défaut) | ☐ |
| Mode d'identification de zone | Quartier/secteur | ☐ (Phase 09) |
| Type(s) de preuve de livraison | Code/photo/confirmation | ☐ (Phase 13) |

---

## H. Critères de validation de la Phase 02

- [ ] Tous les documents J08→J18 sont rédigés et versionnés
- [ ] Toutes les décisions D1-D6 sont explicites
- [ ] Les montants à verrouiller (G) sont identifiés avec valeurs par défaut
- [ ] Le document est signé/validé par la porteuse avant le développement des modules financiers

**Références :** `documentation/phase-02-cadrage-metier/` — J08 à J17 détaillés.