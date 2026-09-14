# J16 — Règles de paiement

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** Validé — **Source :** Plan directeur V1.2, Phase 02, J16

---

## 1. Objet

Définir le cycle complet du paiement mobile money : initiation, confirmation, webhook, échec, expiration, doublon, remboursement et rapprochement.

## 2. Principes de sécurité

1. **Le montant payé est toujours recalculé côté Laravel.** Par défaut, il vaut le `total_client` figé de la commande. Le montant transmis au mobile n'est jamais utilisé tel quel côté serveur.
2. **La confirmation de paiement vient exclusivement du webhook vérifié** (signature + vérification), jamais de la déclaration du mobile.
3. Les traitements sont **idempotents** : un webhook reçu deux fois n'entraîne qu'une seule validation.
4. Aucune clé de paiement ne se trouve dans Flutter, Git ou les réponses API.

## 3. Cycle de vie d'un paiement

```
                   ┌─────────────────────────────────────────────┐
                   │                                             │
initiated ──▶ pending ──▶ confirmed (webhook OK) ──▶ settled
    │              │            │
    │              │            └──▶ failed
    │              └──▶ expired
    └──▶ cancelled
```

| Statut | Description |
|--------|-------------|
| `initiated` | Transaction créée côté backend, lien/flow renvoyé au client |
| `pending` | Paiement attendu / en cours chez l'agrégateur |
| `confirmed` | Webhook vérifié → paiement confirmé, montant contrôlé |
| `failed` | Paiement échoué (utilisateur annule, solde insuffisant…) |
| `expired` | Délai de paiement dépassé, transaction expirée |
| `cancelled` | Commande annulée avant paiement (transaction/verrouillée abandonnée) |
| `settled` | Les fonds sont disponibles/répartis (raccourci au rapprochement) |

## 4. Règles par étape

### 4.1 Initiation
1. Le client valide sa commande (`awaiting_payment`).
2. Le serveur crée une **transaction de paiement** : montant (total_client), référence unique (uuid interne), référence commerçante pour l'agrégateur, devise (XOF), métadonnées.
3. Le serveur appelle l'interface `PaymentGateway` (Kkiapay) pour créer le paiement / obtenir le lien de paiement.
4. Le lien/flow est renvoyé au mobile pour que le client paie.
5. La transaction passe `pending`.

### 4.2 Confirmation (webhook)
1. L'agrégateur envoie un webhook sur l'URL dédiée (`POST /api/v1/webhooks/kkiapay`).
2. Le serveur : vérifie la **signature**, vérifie que la valeur n'est **pas déjà traitée** (idempotence), vérifie que la référence existe dans le système.
3. La commande doit être en `awaiting_payment` (jamais déjà `paid` ni `cancelled`).
4. On **recalcule le montant attendu** (total_client de la commande) et on le compare au montant reçu dans le webhook. Contrôle → on accepte ; sinon gestion d'écart (incident + audit, pas de passage à payé automatique).
5. La transaction passe `confirmed` ; la commande passe `paid` ; le statut est notifié ; les stocks réservés sont confirmés.
6. Les écritures financières (J14) sont créées.

### 4.3 Échec
- L'utilisateur annule le popup de paiement → statut `failed`.
- Le client peut retenter le paiement (nouvelle initiation) tant que la commande est en `awaiting_payment` n'est pas expirée.

### 4.4 Expiration
- **Deadline de paiement** configurable (ex. 15 minutes).
- À expiration : transaction `expired`, commande `cancelled` (motif `expiration_paiement`), stocks réservés libérés.

### 4.5 Doublon
- Un **webhook dupliqué** (même transaction reçue deux fois) est détecté par la clé d'idempotence et ignoré.
- Une **seconde transaction créée pour la même commande** : seule la première confirmation valide ; les transactions suivantes sont marquées `cancelled`/`superseded`.
- Un **webhook en retard** (après expiration) : ne pas marquer la commande payée à tort ; il est tracé et classé `expired`/`late`, puis escalade manuelle si les fonds ont bien été débités (rapprochement).

### 4.6 Remboursement
- Voir J12 (workflow annulation) et J14 (§6.1) : initiation, exécution (API si supporté, sinon manuel tracé), statuts `pending_refund` → `refunded`.

## 5. Table `payment_events` (trace)

Chaque évènement est journalisé : transaction, type (initiated/pending/confirmed/failed/expired/cancelled/webhook_received/webhook_ignored/refund_requested/refund_executed), payload brut (hashé si sensible), date, résultat.

## 6. Rapprochement (J105)

- Comparaison régulière : paiements `confirmed` côté système ↔ statuts côté agrégateur ↔ écritures `order_financials`.
- Tout écart est traité comme un incident et audité.

## 7. Tests obligatoires (J96)

- [ ] Webhook reçu deux fois → une seule validation (idempotence)
- [ ] Montant du webhook != montant attendu → pas de passage à payé
- [ ] Webhook sur commande déjà payée → ignoré
- [ ] Webhook en retard (commande expirée) → pas de payé à tort
- [ ] Échec/annulation par l'utilisateur → statut `failed`, retry possible
- [ ] Expiration → commande `cancelled`, stocks libérés
- [ ] Remboursement → transaction + commande `refunded`

## 8. Critères d'acceptation

- [ ] Interface `PaymentGateway` indépendante du fournisseur (J87)
- [ ] Montant toujours recalculé côté serveur (J94)
- [ ] Webhook vérifié + idempotent (J92)
- [ ] Gestion complète des échecs/expirations/doublons (J93)
- [ ] Confirmation liée à la commande et aux écritures financières (J95)
- [ ] Logs de chaque opération