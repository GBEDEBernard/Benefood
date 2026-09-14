# J35 — Logs, audit & observabilité

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J35

---

## 1. Principes

- Tout événement **financier et de mutation sensible** est journalisé **immuablement** (table `event_log` / `audit_logs`, append-only).
- Aucune donnée sensible (jetons, mots de passe, clés Kkiapay) jamais loggée.
- Logs applicatifs (`laravel.log`) pour débug ; **audit log en base** pour la porteuse (J172 back-office audit view).

## 2. Journal d'audit (immuable)

Table `audit_logs` :
| Champ | Type | Note |
|-------|------|------|
| id | uuid | PK |
| actor_type/actor_id | (user / system / gateway) | qui |
| action | string | slug (ex. `order.paid`) |
| auditable_type/auditable_id | polymorphique | l'entité touchée |
| context | json | avant/après, références |
| ip / user_agent | string | enrichissement |
| occurred_at | datetime | horloge serveur |
- Append-only : **pas d'UPDATE ni DELETE** (contrainte DB niveau API : seuls INSERT admis).
- Immutabilité réaliste : accès limité aux rôles `porteuse`/`admin-technique` (lecture) ; la porteuse reste la partie de contrôle.

## 3. Journal financer

- Les `financial_journal` entities de M9 dans la Finance snapshot : écritures en append-only, chaque ligne = date, type, référence, montant, solde après.
- Le calcul `paid` déclenche `order_financials` (J33) + entrées journal.

## 4. Observabilité (production)

| Brique | Outil |
|--------|-------|
| Logs structurés | channels Laravel (stack) |
| Métriques | counters envoyés (option) — health/uptime basique |
| Erreurs 5xx | alerte (monit/lede) + Slack/webhook notification |
| Trace | corrélation par `uuid` (X-Request-Id) |

### Patterns
- Chaque requête API reçoit un `request_id` (uuid) → renvoyé dans l'enveloppe `meta` (J31) → retrouvé dans les logs.
- Middleware `LogRequests` : méthode, path, status, durée, actor_id, request_id (niveau info, pas les bodies).

## 5. Rétention & taille

| Log | Rétention |
|-----|-----------|
| Application | 30 jours (rotation daily) |
| Audit (base) | conservé (archivage annuel possible) |
| Webhook brut | 90 jours puis purge (comprenant hash de signature) |
| failed_jobs | 30 jours puis purge |

## 6. Revue de sécurité (admin)

- `GET /api/v1/admin/audit-logs` (filter acteur/entité/date) — policy `audit.view` (porteuse/admin).
- Dashboard porteuse : journal commandes/remboursements/payouts (J172).
- Research : index sur `(auditable_type, auditable_id)`, `(actor_id)`, `(action, occurred_at)`.

## 7. Le « impossible state » (safety net)

- Script `logs:reconcile-audit` : vérifie les divergences entre state machine attendue et journal (rare, ex. recherche d'IRLés).
- Alerting sur anomalies (montants négatifs, transitions interdites J30).

## 8. Critères d'acceptation

- [ ] `audit_logs` append-only en place
- [ ] Journal financier annexé systématiquement (paid/refund/payout)
- [ ] request_id propagé dans les logs
- [ ] logs ne contiennent jamais de secrets/PII sensibles
- [ ] Endpoint admin d'inspection audit fonctionnel
- [ ] Rétention définie et purge en place