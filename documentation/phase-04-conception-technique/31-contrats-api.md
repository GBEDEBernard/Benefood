# J31 — Contrats API

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J31

---

## 1. Conventions générales

| Convention | Règle |
|-----------|-------|
| Préfixe | `/api/v1` |
| Authentification | `Authorization: Bearer <sanctum_token>` (sauf auth/login/webhooks) |
| Format | JSON, camelCase |
| Timestamps | ISO-8601 UTC (ex. `2026-09-14T09:00:00Z`) |
| Montants | Entiers en **centimes XOF** (`int`), sauf s'explicitement `decimal` |
| Devise | Toujours présente : `currency: "XOF"` |
| IDs | UUID (strings) |
| Pagination | `?page=2&per_page=25` (max 100) |
| Recherche/Tri | `?search=`, `?sort=-created_at` (préfixe `-` = desc) |
| Filtres | `?status=paid&quarter=Zogbo` etc. |
| Localisation | Header `Accept-Language: fr` (défaut) |

## 2. Enveloppes de réponse

### 2.1 Succès (liste paginée)
```json
{
  "data": [ ... ],
  "meta": { "current_page": 1, "last_page": 5, "per_page": 25, "total": 124 },
  "links": { "first": "/api/v1/orders?page=1", "prev": null, "next": "/api/v1/orders?page=2", "last": "/api/v1/orders?page=5" }
}
```

### 2.2 Succès (objet unique)
```json
{ "data": { ... } }
```

### 2.3 Erreur standard (toujours même shape)
```json
{
  "message": "Texte humain (fr)",
  "errors": { "field": ["message validation"] },
  "code": "auth.invalid_credentials",
  "status": 401,
  "trace_id": "550e8400-..."
}
```

### 2.4 Codes HTTP utilisés
| Code | Usage |
|------|-------|
| 200 | OK / opération GET |
| 201 | Création (POST) |
| 202 | Accepté / traitement async en cours |
| 204 | Succès vide (DELETE) |
| 400 | Requête invalide (paramètres) |
| 401 | Non authentifié |
| 403 | Authentifié mais non autorisé (policy) |
| 404 | Introuvable |
| 409 | Conflit d'état (transition interdite, panier multi-vendeur, doublon) |
| 422 | Validation échouée (`errors.field`) |
| 429 | Rate limit |
| 500 | Erreur serveur (`code` générique, `message` neutre) |
| 503 | Maintenance / indisponible |

## 3. Codes d'erreur métier (dictionnaire évolutif)

```
auth.invalid_credentials      auth.token_expired        auth.account_suspended
auth.phone_not_verified       auth.email_not_verified
user.insufficient_permissions (403)
order.wrong_state             order.payment_deadline    order.snapshot_locked
order.vendor_closed           order.zone_not_served     order.cart_multi_vendor
order.stock_unavailable       order.cannot_cancel       order.cannot_refund
payment.gateway_error         payment.webhook_invalid   payment.webhook_duplicate
payment.amount_mismatch       payment.expired
vendor.not_activated          vendor.suspended
delivery.no_driver_available  delivery.not_your_assignment
delivery.wrong_state
```

## 4. Endpoints de référence (M1-M14)

### Auth & Users
```
POST   /auth/register                {name, phone, email?, password, roles[]}
POST   /auth/login                   {login, password}
POST   /auth/logout
POST   /auth/forgot-password         {login}
POST   /auth/reset-password          {token/code, password}
POST   /auth/verify-phone            {code}
GET    /me                           → user + rôles
GET    /me/roles                     → [{role, is_active}]
POST   /me/active-role               {role_slug}
GET    /me/devices                   ; POST /me/devices {fcm_token, platform}
PATCH  /me                           {name, email?}
```

### Vendors
```
GET    /vendors/me                   (profil + statut)
POST   /vendors/me/onboarding        (infos légales)
POST   /vendors/me/documents         {type, file}
GET    /vendors/me/status
GET    /vendors                      (public : boutiques actives)
GET    /vendors/{id}                 (fiche boutique publique)
PUT    /vendors/me                   (boutique infos)
PUT    /vendors/me/hours             {day, opens_at, closes_at, is_closed}
POST   /vendors/me/toggle-open       {open}
```

### Catalog
```
GET    /categories
GET    /categories/{id}/products
GET    /products                     (filtres : category, q, vendor, in_stock)
GET    /products/{id}
POST   /vendors/me/products
PUT    /vendors/me/products/{id}
DELETE /vendors/me/products/{id}     (soft-disable recommandé)
POST   /products/{id}/images         (upload)
```

### Cart & Checkout
```
GET    /cart
POST   /cart/items                   {product_id, quantity}
PUT    /cart/items/{id}              {quantity}
DELETE /cart/items/{id}
POST   /checkout/quote               {address_id | zone_id, items[]}
POST   /orders                       (créé depuis cart, → awaiting_payment)
```

### Orders
```
GET    /orders                       (client : mes commandes)
GET    /orders/{id}
POST   /orders/{id}/cancel           {reason}
POST   /vendors/me/orders            (liste vendeur)
POST   /orders/{id}/accept           ; /reject {reason}
POST   /orders/{id}/prepare          ; /ready
```

### Payments
```
POST   /orders/{id}/payment          → {payment_url, reference}
GET    /payments/{id}
POST   /webhooks/kkiapay             (public, signature vérifiée)
POST   /payments/{id}/refund         (porteuse)
```

### Delivery
```
POST   /driver/me/availability       {online: true|false}
GET    /deliveries/offers            (livreur : courses proposées)
POST   /deliveries/{id}/accept        ; /decline
POST   /deliveries/{id}/pickup
POST   /deliveries/{id}/deliver      {proof_code?, photo?}
POST   /deliveries/{id}/incident     {type, description, photo?}
GET    /deliveries/me                (livreur : historique)
```

### Finance
```
GET    /finance/summary              (collaborateur/wallet)
GET    /vendors/me/earnings
GET    /vendors/me/wallet            ; /wallet/transactions
GET    /drivers/me/earnings
```

### Admin (porteuse) — /api/v1/admin
```
GET    /admin/dashboard
GET    /admin/vendors                ; POST /admin/vendors/{id}/approve|suspend|activate|close
GET    /admin/clients
GET    /admin/drivers                ; POST /admin/drivers/{id}/validate|suspend|activate
GET    /admin/orders                 ; POST /admin/orders/{id}/cancel
GET    /admin/payments               ; POST /admin/refunds
GET    /admin/refunds
GET    /admin/redeems (réclamations) ; POST /admin/complaints/{id}/reply|close
GET    /admin/commission-rates       ; POST /admin/commission-rates
GET    /admin/zones                  ; POST/PUT /admin/zones ; POST /admin/delivery-rates
GET    /admin/audit-logs
GET    /admin/reports/{type}         (export)
```

## 5. Exemples de payload

### `POST /auth/register`
```json
{ "name": "Awa", "phone": "+22997000000", "email": "awa@mail.com",
  "password": "secret123", "roles": ["client"] }
```
→ 201 `{ "data": { "user": {...}, "roles": [{"slug":"client"}], "access_token": "..." } }`

### `POST /checkout/quote`
```json
{ "address_id": "uuid", "items": [{"product_id":"uuid","quantity":2}] }
```
→ 200
```json
{ "data": {
  "vendor_id": "uuid", "subtotal": 5000, "discount": 0, "delivery_fee": 800,
  "total": 5800, "currency": "XOF", "zone_id": "uuid"
} }
```

### `POST /orders`
→ 201 `{ "data": { "id": "uuid", "reference": "BF-202609-0001", "status": "awaiting_payment",
  "payment": { "reference": "pay_...", "url": "https://pay.kkiapay.me/...", "expires_at": "..." } } }`

## 6. Versioning

- Routes courant → `/api/v1`. Breaking change → `/api/v2`, dépérissement de v1.
- Header `Accept-Version` optionnel ; privilégier le préfixe.

## 7. Documentation API

- Générée (Scribe/l5-swagger à choisir à Phase 05) depuis les tests/attributes.
- Swagger exporté pour le back-office.

## 8. Critères d'acceptation

- [ ] Contrats JSON cohérents (enveloppe, erreurs, pagination)
- [ ] Dictionnaire de codes d'erreur maintenu
- [ ] Liste endpoints complète par module
- [ ] Exemples de payload fournis (§5)
- [ ] Versioning `/api/v1` en place