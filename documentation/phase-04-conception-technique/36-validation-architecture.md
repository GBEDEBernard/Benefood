# J36 — Validation de l'architecture, du schéma et des contrats API

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J36

---

## 1. Objectif

Valider la cohérence interne de la Phase 04 : architecture (J26), modules (J27), MCD/MLD (J28), tables+index (J29), machine à états (J30), contrats API (J31), policies (J32), événements (J33), média (J34), logs/audit (J35). Produire une **checklist exécutable** qui servira de référence aux phases 05+ (backend) et 17 (mobile).

## 2. Checklist de validations

### 2.1 Cohérence MCD/MLD ↔ Tables
- [ ] Chaque entité du MCD a sa table dans `29-tables-index.md` (et inversement)
- [ ] Chaque table a un `uuid` PK, `created_at`/`updated_at`
- [ ] Toutes les FK pointent des PK uuid
- [ ] Les cardinalités mono-vendeur sont respectées (orders.cart_id 1:1 ; order_items n:1 orders ; mono vendor par order)
- [ ] Les index fins listés (fk, lookups métier) sont présents

### 2.2 Cohérence Machine à états ↔ API
- [ ] Chaque endpoint d'action de commande correspond à une transition J30 (ou 409 si interdite)
- [ ] Les deadlines (paiement, livraison) ont un champ horodaté en base
- [ ] Toute nouvelle transition interdit doit retourner 409 Conflict, jamais 200

### 2.3 Cohérence Contrats API ↔ Modules
- [ ] Chaque module M1–M14 expose endpoints conformes à `31-contrats-api.md`
- [ ] Enveloppes `{data, meta, errors}` identiques sur toutes les routes
- [ ] Codes d'erreur normalisés (validation 422, unauthorized 401, forbidden 403, not found 404, conflict 409, server 5xx)
- [ ] Pagination et filtres homogènes

### 2.4 Cohérence RBAC ↔ API
- [ ] Chaque endpoint admin sous permission `admin.*`
- [ ] Chaque ressource propriétaire protégée par policy (IDOR interdit) — cf. J32 §7
- [ ] Le cumul de rôles et contexte actif ne change jamais l'authorization

### 2.5 Cohérence Paiements ↔ Machine à états
- [ ] Le webhook Kkiapay confirmé → transition `paid` uniquement si statut `awaiting_payment` et montant == attendu
- [ ] Late webhook ignoré (J16/J33)
- [ ] Refund seulement déclenché sur statuts éligibles (J30)

### 2.6 Cohérence Événements ↔ Notifications
- [ ] Chaque événement (J33 §2) correspond à des notifications définies (J33 §3)
- [ ] Chaque job est dispatché depuis le bon point de la machine à états

### 2.7 Montants & finances
- [ ] Tous les montants en centimes XOF (int) — aucune décimale en API
- [ ] La décomposition `order_financials` est calculée à `paid` (services, jamais coté client)
- [ ] Chaque mouvement financier a une entrée de journal (append-only)

### 2.8 Média & stockage
- [ ] Documents privés jamais servis en public (J34 §6)
- [ ] Validation stricte upload (mime/taille) au niveau serveur

### 2.9 Observabilité
- [ ] `request_id` propagé; audit append-only; endpoint admin d'inspection

## 3. Contrat de référence consolidé (récapitulatif API)

- Base URL : `https://api.beninfood/{env}/api/v1` (doc J31 §1)
- Headers : `Authorization: Bearer <token>` ; `Content-Type: application/json` ; `X-Request-Id`
- Enveloppe success : `{"data": …}`
- Enveloppe erreur : `{"errors": [{"code","message","field"}]}`
- Pagination : `?page=`, réponse `{ "data": […], "meta": {page, per_page, total, last_page} }`

## 4. Récit de bout en bout (smoke test cible, référence)

1. Client s'inscrit, se connecte (`POST /auth/login`).
2. Client parcourt le catalogue (catégorie → produits).
3. Client crée un panier mono-vendeur, ajoute des articles.
4. Client passe commande → `awaiting_payment` + initie paiement Kkiapay.
5. Webhook confirmé → `paid` + notifications livraison.
6. Vendeur accepte → `accepted`.
7. Vendeur marque `ready` → offre de course au(x) livreur(s).
8. Livreur accepte → `assigned` + livre → `delivered` + preuve.
9. Client note/review + livraison confirmée.
10. Porteuse consulte dashboard/audit et lance un payout vendeur.

Ce récit doit passer de bout en bout avec l'API réelle (tests d'intégration) en phase 10 (J77-J86).

## 5. Livrables de la Phase 04 (rappels)

- [ ] 7 documents J26→J35 rédigés et commités (cette Phase)
- [ ] Cette checklist J36 validée en relisant chaque doc
- [ ] Aucune information obsolète ou contredisant Phases 02/03

## 6. Critères d'acceptation (Phase 04)

- [ ] L'architecture est cohérente sur l'axe « commande → paiement → livraison → finance »
- [ ] Les contrats API sont stables et testables (utilisables par les équipes mobile/back-office)
- [ ] Les questions ouvertes restantes pour les phases suivantes sont listées (ci-dessous)

## 7. Questions ouvertes (à trancher en phases suivantes)

| N° | Question | À trancher en |
|----|----------|---------------|
| Q1 | Livreur Béninfood : salarié vs indépendant (part delivery_fee) | Phase 02 déjà travaillée — à confirmer porteuse |
| Q2 | Affectation de course : manuel vs auto (géolocation) | Phase 06/13 |
| Q3 | Reversements wallet : réel décaissement incluant Kkiapay | Phase 10 (finance) |
| Q4 | Notification SMS (via agrégateur ?) | Phase 13 |
| Q5 | Période de grâce avant `ready` (cuisine) — délai acceptation | Phase 07+ |