# J26 — Architecture API-first

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J26

---

## 1. Vue d'ensemble

```
                          ┌──────────────────────────────────────────┐
                          │         FLUTTER (1 app multi-rôles)      │
                          │  core / shared / auth / client / vendor / │
                          │  driver / router                          │
                          └───────────────┬──────────────────────────┘
                                          │ HTTPS + JSON (tokens Sanctum)
                                          ▼
                             ┌─────────────────────────┐
                             │   LARAVEL API (/api/v1) │
                             │  Auth-RBAC · métier ·   │
                             │  paiement · finance ·   │
                             │  livraison · notif ·    │
                             │  audit                  │
                             └────┬──────┬─────┬───────┘
                                  │      │     │
                 ┌────────────────┘      │     └───────────────┐
                 ▼                       ▼                     ▼
        ┌───────────────┐     ┌────────────────┐    ┌────────────────────┐
        │ Back-office   │     │ Queue/Jobs     │    │ Services externes  │
        │ web (porteuse)│     │ (DB driver)    │    │ Kkiapay · FCM · SMS│
        └───────┬───────┘     └────────────────┘    └────────────────────┘
                │                        │
                ▼                        ▼
        ┌─────────────────────────────────────────────┐
        │               MySQL (source de vérité)       │
        │  migrations + seeders + backup              │
        └─────────────────────────────────────────────┘
```

## 2. Principes directeurs

| Principe | Description |
|----------|-------------|
| **API-first** | Toute la logique métier et financière est dans Laravel ; Flutter et le back-office consomment la même API `/api/v1`. |
| **Versionnée** | Routes mobiles/publiques en `/api/v1`. Ajout rétro-compatible : `/api/v2` si breaking. |
| **Stateless API** | Sessions mobiles sans état côté serveur : tokens Sanctum. |
| **Serveur = vérité** | Montants, permissions, statuts : toujours calculés/appliqués côté Laravel. |
| **Policies** | Authorization via Policies + Gates (RBAC), jamais via le rôle déclaré par le mobile. |
| **Externalités isolées** | Kkiapay, FCM, stockage derrière des interfaces/adapters (réversibilité). |
| **Asynchrone** | Jobs/queues DB par défaut pour webhooks, notifications, mails, recalculs. |

## 3. Structure backend Laravel (dossier de référence)

```
app/
├── Http/
│   ├── Controllers/Api/V1/          → contrôleurs API versionnés par contexte
│   ├── Requests/                    → Form Requests (validation)
│   │    (Auth/RegisterRequest, Orders/PlaceOrderRequest, …)
│   └── Resources/                   → API Resources (JSON contracts)
├── Models/                          → Eloquent models domain
├── Policies/                        → Policies par entité
├── Services/                        → logique métier (OrderService, PaymentService, CommissionService, DeliveryService…)
├── Gateways/                        → adapters externes (PaymentGateway, FcmGateway, StorageGateway)
├── Events/ & Listeners/             → domain events + listeners
├── Jobs/                            → jobs queued (ProcessWebhook, SendPush…)
├── Observers/                       → model observers (statut, notifications)
├── Support/                         → helpers, Enums, StateMachines
└── Traits/                          → HasUuids, Auditable…
config/beninfood/                    → paramètres métier (commission, délais…)
routes/api.php                       → versionnement /api/v1
database/migrations + seeders + factories
tests/Unit + tests/Feature
```

## 4. Structure Flutter (référence J144+)

```
lib/
├── main.dart
├── app/app.dart
├── router/app_router.dart          → go_router (auth redirect, contexts, deep-links)
├── core/
│   ├── auth/                       → session, auth state (Provider)
│   ├── http/                       → ApiClient, interceptors, token refresh
│   ├── storage/                    → SecureStorage (tokens) + SharedPrefs (préfs)
│   ├── config/app_config.dart      → base URL, env
│   └── theme/app_theme.dart
├── shared/widgets/                 → design system (J24)
└── features/
    ├── auth/                       → screens, providers, services
    ├── client/
    ├── vendor/
    └── driver/
```
Chaque feature : `data/` (models + services API), `domain/` (si règles de présentation), `presentation/` (providers + screens + widgets).

## 5. Décisions d'implémentation initiales

| Sujet | Décision V1.2 |
|-------|---------------|
| **PHP / Laravel** | PHP 8.4+, Laravel 13 (installé) |
| **Auth API** | Laravel Sanctum (déjà installé), tokens bearer |
| **Base de données** | MySQL (déjà configuré `beninfood`), moteur InnoDB, charset utf8mb4 |
| **Queue** | Driver `database` (config actuelle), transformable Redis en prod |
| **Cache** | Driver `database` (défaut), Redis en prod possible |
| **UUID** | IDs UUID (HasUuids) pour entités exposées à l'API (prévention enumeration IDOR) |
| **Devise** | XOF, montants entiers en **centimes** (integer) |
| **Langue** | Français (fr), codes API en anglais (statuts) |

## 6. Critères d'acceptation

- [ ] Architecture approuvée (ce document)
- [ ] Structure `app/` conforme §3
- [ ] Structure Flutter `lib/features/` conforme §4
- [ ] Toutes les externalités derrière des gateways/adapters
- [ ] Versioning API actif (`/api/v1`)