# J33 — Événements, jobs, queues & webhooks

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J33

---

## 1. Queue par défaut

- Driver queue : **database** (config mobilisée). Production : réservoir Redis recommandé.
- Les jobs lents (webhooks, notifications, mails) sont dispatchés `->onQueue('notifications')`, `('payments')`, `('delivery')`, `('finance')` pour isolation.

## 2. Événements métier (Domain Events)

| Event | Déclencheur | Écouteurs / jobs en côte |
|-------|-------------|--------------------------|
| `UserRegistered` | inscription | SendWelcomeEmail, SendOtp |
| `UserRolesChanged` | admin/inscription multi-rôles | Audit |
| `VendorRegistered` | onboarding vendeur | NotifyPorteuse |
| `VendorSubmitted` | documents soumis | NotifyPorteuse |
| `VendorStatusChanged` | validate/suspend/activate | NotifyVendor |
| `ProductCreated/Updated` | CUD produit | CatalogSearchIndexer (option) |
| `OrderCreated` | ordre passe awaiting_payment | SchedulePaymentDeadline |
| `OrderPaid` | webhook confirmé | NotifyVendor, CreateFinancials, ReserveStockConfirm |
| `OrderAccepted` | vendeur accepte | NotifyClient |
| `OrderReady` | vendeur marque prête | TriggerDeliveryAssignment |
| `OrderDelivered` | livreur livre | CreateFinancials(delivery), NotifyClient, AllowReview |
| `OrderCancelled` | annulation | DetermineRefund, ReleaseStock, NotifyAll |
| `OrderRefunded` | remboursement exécuté | NotifyClient, FinancialJournal |
| `PaymentFailed` | échec paiement | NotifyClient (retry prompt) |
| `PaymentExpired` | deadline | CancelOrder (si besoin) |
| `WebhookReceived` | webhook entrant | ProcessWebhook |
| `DeliveryOffered` | affectation proposée | NotifyDriver |
| `DeliveryAccepted` | livreur accepte | NotifyVendor+Client |
| `DeliveryIncident` | incident livreur | NotifyPorteuse |
| `ComplaintOpened/Resolved` | réclamation | NotifyUser, NotifyPorteuse |
| `PayoutExecuted` | reversement | NotifyVendor/Driver |

### 3. Map événement → notification (J126-J132)

| Event | Push | Email | SMS | Deep-link |
|-------|:----:|:-----:|:---:|-----------|
| OrderPaid | ✅ vendeur | — | — | /vendor/orders/{id} |
| OrderAccepted | ✅ client | — | — | /client/orders/{id} |
| OrderReady | ✅ client | — | — | /client/orders/{id} |
| OrderAssigned | ✅ client | — | — | /client/orders/{id} |
| OrderDelivered | ✅ client (+livreur) | — | — | /client/orders/{id} |
| DeliveryOffered | ✅ livreur (priorité) | — | — | /driver/missions/{id} |
| OrderCancelled | ✅ tous | email si refund | ✅ cas retenus | selon rôle |
| OrderRefunded | ✅ client | ✅ | — | /client/orders/{id} |
| PaymentFailed/Expired | ✅ client | — | — | /client/orders/{id} |
| VendorSuspended | ✅ vendeur | ✅ | — | /vendor/profile |
| DriverSuspended | ✅ livreur | ✅ | — | /driver/profile |

## 4. Jobs (liste)

| Job | Queue | But |
|-----|-------|-----|
| `SchedulePaymentDeadline` | default | donne le deadline paiement (deadline at) |
| `ExpirePendingPayments` | default (scheduled) | passe `awaiting_payment` → cancelled si deadline atteinte — **idempotent** |
| `ProcessKkiapayWebhook` | payments | vérifie + confirme paiement (idempotence) |
| `HandlePaymentWebhookEvent` | payments | met à jour paiement |
| `DispatchDeliveryAssignment` | delivery | cherche livreur online pour `ready` |
| `NotifyDriverOfOffer` | notifications | push offre course |
| `ProcessProofDelivery` | delivery | valide preuve (async) |
| `DispatchRefund` | payments/finance | exécute refund Kkiapay |
| `CalculateAndSnapshotFinancials` | finance | crée order_financials sur paid |
| `ProcessPayout` | finance | exécute reversement wallet |
| `SendPushNotification` | notifications | via FcmGateway |
| `SendEmailNotification` | notifications | mails |
| `SendSmsNotification` | notifications | SMS (cas retenus) |
| `RotateExpiredTokens` / `UpdateDriverOnlineStatus` | default (scheduled) | maintenance |

## 5. Scheduler (cron)

| Fréquence | Commande | Action |
|-----------|----------|--------|
| toutes les minutes | `orders:expire-payments` | expiration paiements (idempotent) |
| toutes les minutes | `deliveries:assign` | affectation des courses prêtes (si automatique) |
| toutes les 15 min | `payments:reconcile` | rapprochement agrégateur (J105) |
| quotidienne | `reports:daily` | envoi rapport quotidien porteuse (optionnel) |
| quotidienne | `tokens:cleanup` | nettoyage tokens périmés |
| hebdo | `log:cleanup` | purge système logs (rétention configurable) |

## 6. Webhooks (entrants — Kkiapay)

### 6.1 Traitement
1. **Validation de signature** (clé secrète, en-tête HTTP) — refus 401 si invalide.
2. Enregistrement brut dans `webhook_events` (payload, signature, reçu à).
3. Déduplication : clé d'idempotence = `gateway_txn_id` (index unique) → si déjà traité, retour 200 immédiatement.
4. `ProcessKkiapayWebhook` : vérifie paiement existant, montant attendu, statut commande, puis transition `paid` (J30/T3) + journal.
5. Réponse HTTP rapide (200) même si job async ; retry gemé par queue.

### 6.2 Erreurs
- Job failed → retry (backoff), après max retries → `failed_jobs` + alerte (J35).
- Webhook "late" (après expiration) : loggé comme événement, **ne passe pas** la commande en paid (J16).
- Tout webhook non reconnu → 422 + loggé.

## 7. Idempotence

- Webhooks : unique `gateway_txn_id`.
- Refund : unique `(payment_id, amount)` pour éviter double remboursement.
- Payout : unique `(wallet_id, reference)`.
- Expiration : conditionnelle sur `status == awaiting_payment` (UPDATE ... WHERE).
- Notifications : passage par type + référence si besoin.

## 8. Critères d'acceptation

- [ ] Queue DB active + workers (queue:work) pour paiements/notifications
- [ ] Événements émis aux bons moments (machine états)
- [ ] Jobs programmés (scheduler) en place
- [ ] Webhooks signature + idempotence + retry testés
- [ ] Le « late webhook » n'est jamais traité comme paiement valide