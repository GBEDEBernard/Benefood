# J28 — MCD / MLD et cardinalités

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J28

---

## 1. Modèle conceptuel (MCD) — vue entités/relations

```
USERS (1,N)──(0,N) ROLES                →  users_roles (pivot)
USERS (1,1)──(0,N) USER_DEVICES
USERS (1,1)──(0,N) ADDRESSES
USERS (1,1)──(0,N) VENDORS
USERS (1,1)──(0,N) DRIVER_PROFILES
VENDORS (1,1)──(0,N) PRODUCTS
VENDORS (1,1)──(0,N) VENDOR_DOCUMENTS
VENDORS (1,1)──(0,N) VENDOR_HOURS
CATEGORIES (1,0)──(0,N) CATEGORIES       →  catégorie parent (self-ref)
PRODUCTS (1,1)──(0,N) PRODUCT_IMAGES
PRODUCTS (0,1)──(0,N) STOCKS/stock_logs → ou stock inline selon décision
PRODUCTS (1,1)──(0,N) PRODUCT_VARIANTS  (option)

CARTS (1,1)──(0,N) CART_ITEMS
CART_ITEMS (N,1)──(1,1) PRODUCTS
CART_ITEMS (N,1)──(1,1) VENDORS          → mono-vendeur garanti par contrainte

ORDERS (1,1)──(1,1) CARTS               →  reference (rattacher cart/order)
ORDERS (N,1)──(1,1) USERS (client)
ORDERS (N,1)──(1,1) VENDORS
ORDERS (1,1)──(0,N) ORDER_ITEMS
ORDERS (1,1)──(0,N) ORDER_STATUS_HISTORY
ORDERS (1,1)──(0,1) DELIVERY (course)
ORDERS (1,1)──(0,1) ORDER_FINANCIALS
ORDERS (1,1)──(0,N) PAYMENTS

PAYMENTS (1,1)──(0,N) PAYMENT_EVENTS
PAYMENTS (1,1)──(0,1) REFUNDS

COMMISSION_RATES (1,N)──(0,N) (appliqué à) ORDERS  → snapshot dans order_financials
DELIVERY_ZONES (1,1)──(0,N) DELIVERY_RATES
DELIVERY_RATES (N,1)──(0,1) VENDORS     →  tarif spécifique vendeur (nullable)
ADDRESSES (1,1)──(0,1) DELIVERY_ZONES   →  zone déduite (sélection) 

DRIVER_PROFILES (1,1)──(0,N) DELIVERIES (course: affects assignée)
DELIVERIES (1,1)──(0,N) DELIVERY_STATUS_HISTORY
DELIVERIES (1,1)──(0,N) (preuves) PROOF_MEDIA

USERS (1,1)──(0,N) REVIEWS
PRODUCTS (1,1)──(0,N) REVIEWS
ORDERS (1,1)──(0,1) REVIEWS (une commande → un avis produit)

USERS (1,1)──(0,N) COMPLAINTS
ORDERS (1,1)──(0,N) COMPLAINTS
COMPLAINTS (1,1)──(0,N) COMPLAINT_MESSAGES
COMPLAINTS (1,1)──(0,N) ATTACHMENTS

FINANCE : WALLETS (1,1)──(0,N) WALLET_TRANSACTIONS
          WALLETS (1,1)──(0,N) PAYOUTS
          ORDER_FINANCIALS ──► journal entries (append-only)

NOTIFICATIONS (USER-target) , NOTIFICATION_TEMPLATES
AUDIT_LOGS, WEBHOOK_EVENTS, SYSTEM_LOGS (append-only)
```

## 2. MLD — liste des tables (logique relationnelle)

### Contexte Auth & Users
- `users`
- `roles`
- `permissions`
- `role_permission` (pivot)
- `user_roles` (pivot polyvalent)
- `user_devices`
- `addresses`
- `password_reset_tokens` (Laravel défaut)

### Contexte Vendors
- `vendors`
- `vendor_documents`
- `vendor_hours`
- `vendor_status_history`
- `vendor_settings` (ex. partage livraison, exceptions commission)

### Contexte Catalog
- `categories`
- `products`
- `product_images`
- `product_variants` (option)
- `product_price_history` (versioning prix — J65)
- `stocks` (ou stock inline produits) + `stock_logs`

### Contexte Cart
- `carts`
- `cart_items`

### Contexte Orders
- `orders`
- `order_items`
- `order_status_history`

### Contexte Payments & Finance
- `payments`
- `payment_events`
- `refunds`
- `commission_rates`
- `order_financials`
- `wallets`
- `wallet_transactions`
- `payouts`
- `financial_journal` (append-only général)

### Contexte Delivery
- `delivery_zones`
- `delivery_rates`
- `deliveries`
- `delivery_status_history`
- `driver_profiles`
- `driver_documents`
- `driver_availability_logs`

### Contexte Support
- `reviews`
- `complaints`
- `complaint_messages`
- `attachments`

### Contexte Notifications & Audit
- `notifications`
- `notification_templates`
- `audit_logs`
- `webhook_events`
- `system_logs`

## 3. Cardinalités clés et contraintes

| Contrainte | Règle |
|-----------|-------|
| **Panier mono-vendeur** | Une table `carts`= vendeur unique + index unique sur (cart_id, product_id) pour éviter les doublons de ligne ; la quote vérifie le vendeur unique. |
| **Snapshot order_items** | Les champs `name`, `unit_price`, `quantity`, `subtotal` copiés (pas de FK vers produits pour la lecture historique — ou FK nullable pour traçage). |
| **1 commande → 0..1 livraison** | La commande délègue sa course à `deliveries` ; une course est liée à une seule commande. |
| **1 commande → 1 order_financials** | Unique 1:1 (snapshot). |
| **UUID** | Clés primaires UUID (`HasUuids`) pour entités exposées. |
| **Historisation** | Statuts (commandes, vendeurs, livreurs) → tables dédiées d'historique append-only. |
| **Journal financier** | `financial_journal` append-only ; les autres tables ne sont jamais UPDATÉES pour corriger un montant (écriture de correction). |

## 4. Critères d'acceptation

- [ ] MCD/MLD révisés (passage à J29 pour liste exhaustive)
- [ ] Cardinalités respectées dans les migrations
- [ ] Contraintes métier (mono-vendeur, snapshots, 1:1 financier) explicitées
- [ ] Tables d'historique et journal prévues