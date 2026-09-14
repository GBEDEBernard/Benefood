# J27 — Bounded contexts & modules

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J27

---

## 1. Liste des bounded contexts (modules)

| # | Contexte | Responsabilités |
|---|----------|-----------------|
| M1 | **Auth** | Inscription, connexion, OTP, reset password, tokens, sessions |
| M2 | **Users & Roles** | Profils, rôles, permissions, `user_roles`, `user_devices`, contextes actifs |
| M3 | **Vendors** | Profils vendeurs, documents, workflow validation, statuts |
| M4 | **Catalog** | Catégories, produits, images, disponibilité, prix |
| M5 | **Cart** | Panier mono-vendeur, lignes, quote, contraintes |
| M6 | **Orders** | Commande, machine à états, snapshot `order_items`, historique |
| M7 | **Payments** | Transactions, gateway Kkiapay, webhooks, refunds, rapprochement |
| M8 | **Finance** | Commission, `order_financials`, wallet, journal immuable, payouts |
| M9 | **Delivery** | Zones, tarifs, livreurs, affectation, courses, preuve |
| M10 | **Notifications** | FCM, tokens appareils, templates, événements, deep-links |
| M11 | **Reviews** | Avis/notes produits après livraison |
| M12 | **Complaints** | Réclamations client/livreur, messages, résolution |
| M13 | **Admin / Back-office** | Dashboard, pilotage porteuse, réglages métier |
| M14 | **Audit** | `audit_logs`, `webhook_events`, `system_logs` |

## 2. Frontières et dépendances entre modules

```
M1 Auth ──► M2 Users&Roles
M2 Users&Roles ──► M13 Admin (construit les profils admin)
M3 Vendors ──► M2 (user_id)  ◄── M13 (validation)
M4 Catalog ──► M3 (vendor_id)
M5 Cart ──► M4 + M3
M6 Orders ──► M5 (cart), M3 (vendor), M9 (zone/tarif), M7 (payment), M8 (financial)
M7 Payments ──► M6 (order), M8 (journal)
M8 Finance ──► M6, M7, M9 (part livreur)
M9 Delivery ──► M6, M8 (gains livreur)
M10 Notifications ──► tous (événements) 
M11 Reviews ──► M4 (product), M6 (order)
M12 Complaints ──► M6, M8 (remboursement), M13 (résolution)
M13 Admin ──► M1..M12 (lecture/actions autorisées)
M14 Audit ──► tous (side-effect passif)
```

> Règle : les modules ne s'appellent pas entre eux via HTTP — ils utilisent les **Services** communs et les **Events** dans une seule app Laravel. En cas de split V2, chaque module devient un micro-service consommateur de`/api/v1` (limite anticipe).

## 3. Organisation des services en Laravel

| Service | Contexte | Rôle |
|---------|----------|------|
| `AuthService` | M1 | Délivre l'inscription/login/reset |
| `RoleService` | M2 | Associe rôles, vérifie permissions |
| `VendorService` | M3 | Workflow inscription→verification→activation |
| `CatalogService` | M4 | CUD produits, tags, disponibilité |
| `CartService` | M5 | Gère panier + quote (serveur) |
| `OrderService` | M6 | Création commande, transitions, snapshot |
| `PaymentService` | M7 | Initie/confirme/refund, filtre webhooks |
| `PaymentGateway` | M7 | Interface abstraite (Kkiapay impl) |
| `CommissionService` | M8 | Calcule et figure commission |
| `FinanceService` | M8 | Journal immuable, wallet, payouts |
| `DeliveryZoneService` | M9 | Zones/tarifs, sélection de zone |
| `DeliveryService` | M9 | Affectation, statuts course |
| `NotificationService` | M10 | Build + envoi push/email/sms |
| `FcmGateway` | M10 | Adapter FCM |
| `ReviewService` | M11 | Avis produits |
| `ComplaintService` | M12 | Réclamations + résolution |
| `AuditService` | M14 | Écriture des logs d'audit |
| `MediaService` | M4/M3 | Upload/compression (J34) |

## 4. Exemple de routage par module (contour)

```
/api/v1/auth/*            → M1
/api/v1/me/*              → M2 (+ contextes)
/api/v1/vendors*          → M3
/api/v1/categories, /products → M4
/api/v1/cart, /checkout   → M5
/api/v1/orders*           → M6
/api/v1/payments, /webhooks → M7
/api/v1/finance/*         → M8
/api/v1/delivery*, /deliveries* → M9
/api/v1/notifications     → M10
/api/v1/reviews           → M11
/api/v1/complaints        → M12
/api/v1/admin/*           → M13
```

## 5. Critères d'acceptation

- [ ] Chaque contexte a des responsabilités uniques
- [ ] Dépendances acycliques (graphe §2)
- [ ] Services typés par contexte dans `app/Services`
- [ ] Routage `/api/v1/<module>` cohérent
- [ ] Réversibilité (gateways) pour externe (Kkiapay, FCM, stockage)