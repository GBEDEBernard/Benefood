# J29 — Tables principales et index

**Projet :** Béninfood — **Version :** 1.2 — **Date :** Septembre 2026
**Statut :** À valider — **Source :** Plan directeur V1.2, Phase 04, J29

---

> Ce document liste les tables du schéma cible avec les champs principaux et les **index recommandés**. Les migrations seront écrites à partir de cette référence. Toutes les PK = UUID (sauf pivots composites à la convenance).

## 1. Users & Roles

### `users`
- id (uuid), name, phone (unique), email (nullable, unique), password, status (enum: active/suspended/closed), email_verified_at, phone_verified_at, locale, timestamps

### `roles`
- id (uuid), name (unique), slug (unique), description, guard

### `permissions`
- id (uuid), name (unique), slug (unique), module

### `role_permission` (pivot)
- role_id (FK), permission_id (FK) — PK composite (role_id, permission_id)

### `user_roles`
- user_id, role_id, is_active (contexte courant), last_used_at, PK (user_id, role_id)
- **Index** : `user_roles.user_id` , `user_roles.role_id`, unique (user_id, role_id)

### `user_devices`
- id, user_id, fcm_token (unique), platform (android/ios/web), device_type, app_version, is_active, last_seen_at
- **Index** : `user_devices.fcm_token` unique ; `user_devices.user_id`

### `addresses`
- id, user_id, label, zone_id (nullable FK), is_default, full_address, landmark, latitude (nullable), longitude (nullable), city
- **Index** : `addresses.user_id`, `addresses.zone_id`

## 2. Vendors

### `vendors`
- id, user_id (unique → un utilisateur = un profil seller), business_name, legal_name (nullable), ifu (nullable), description, logo_url, cover_url, phone, email (nullable), city, address, status (enum J09), approved_at, closed_at, timestamps
- **Index** : `vendors.user_id` unique ; `vendors.status`

### `vendor_documents`
- id, vendor_id, type (id_card/commerce/photo…), file_path, status (submitted/valid/invalid), reason, submitted_by, reviewed_by (nullable), reviewed_at (nullable)
- **Index** : `vendor_documents.vendor_id`, `vendor_documents.status`

### `vendor_hours`
- id, vendor_id, day_of_week (0-6), opens_at, closes_at, is_closed
- **Index** : `vendor_hours.vendor_id`, unique (vendor_id, day_of_week)

### `vendor_status_history`
- id, vendor_id, from_status, to_status, reason, actor_type (system/porteuse/vendeur), actor_id, created_at
- **Index** : `vendor_status_history.vendor_id`

### `vendor_settings`
- id, vendor_id (unique), commission_exception_rate (nullable), delivery_fee_share (nullable), max_preparation_minutes, auto_accept (bool)
- **Index** : `vendor_settings.vendor_id` unique

## 3. Catalog

### `categories`
- id, parent_id (nullable, self FK), name, slug, icon_path, sort_order, is_active
- **Index** : `categories.parent_id`, `categories.slug` unique

### `products`
- id, vendor_id, category_id, name, description (nullable), unit (pièce/kg/pack…), price (int, centimes XOF), is_active, is_available, stock_qty (int, nullable = illimité), image_main (path), status
- **Index** : `products.vendor_id`, `products.category_id`, `products.is_active`, fulltext `name`

### `product_images`
- id, product_id, path, is_main, sort_order
- **Index** : `product_images.product_id`

### `product_price_history`
- id, product_id, old_price, new_price, changed_by, changed_at
- **Index** : `product_price_history.product_id`

### `stock_logs`
- id, product_id, delta (int ±), qty_after, reason (sale/restock/adjust), reference_type/ref_id, created_at
- **Index** : `stock_logs.product_id`

## 4. Cart

### `carts`
- id, user_id, vendor_id, status (open/checked_out), expires_at (nullable)
- **Index** : `carts.user_id`, unique (user_id, status) partiel impossible facilement → index composé `(user_id, status)`

### `cart_items`
- id, cart_id, product_id, quantity, unit_price, subtotal
- **Index** : unique (cart_id, product_id) ; `cart_items.cart_id`

## 5. Orders

### `orders`
- id, reference (unique, ex. `BF-202609-XXXX`), user_id (client), vendor_id, status (enum J11), currency (XOF), delivery_fee (int), discount (int), subtotal (int), total (int), payment_deadline_at, accepted_at, delivered_at, cancelled_at (nullable), zone_id, address_snapshot (json), cancellation fields (cancellation_reason, cancelled_by)
- **Index** : `orders.user_id`, `orders.vendor_id`, `orders.status`, `orders.created_at`, `orders.reference` unique

### `order_items`
- id, order_id, product_id (nullable), name_snapshot, unit_price_snapshot, quantity, subtotal, variant_label (nullable)
- **Index** : `order_items.order_id`, `order_items.product_id`

### `order_status_history`
- id, order_id, from_status, to_status, actor_type/actor_id, reason (nullable), created_at
- **Index** : `order_status_history.order_id`

## 6. Payments

### `payments`
- id, order_id, reference (unique), gateway (kkiapay…), gateway_txn_id (nullable, unique index), amount (int), currency, status (enum J16), payload (json nullable), paid_at, expires_at
- **Index** : `payments.order_id`, `payments.gateway_txn_id` unique, `payments.status`

### `payment_events`
- id, payment_id, event_type (initiated/pending/webhook/confirmed/failed/expired/cancelled/refund…), payload (json, hash sensible), created_by, created_at
- **Index** : `payment_events.payment_id`

### `refunds`
- id, payment_id, order_id, amount, reason, status (pending/executed/failed), gateway_refund_id (nullable), executed_at, executed_by
- **Index** : `refunds.payment_id`, `refunds.order_id`

## 7. Finance

### `commission_rates`
- id, rate (int, ex 10 = 10 %), effective_from, effective_to (null = current), is_active, notes, created_by
- **Index** : `commission_rates.effective_from`, `commission_rates.is_active`

### `order_financials`
- id, order_id (unique), subtotal, discount, delivery_fee, payment_fee, commission_base, commission_rate, commission_amount, vendor_amount, delivery_partner_amount, platform_amount, total_client, currency, payment_reference
- **Index** : `order_financials.order_id` unique

### `wallets`
- id, owner_type (vendor/driver), owner_id, balance (int)
- **Index** : unique (owner_type, owner_id)

### `wallet_transactions`
- id, wallet_id, type (credit/debit), amount, reference_type/ref_id, description, balance_after, created_at
- **Index** : `wallet_transactions.wallet_id`, unique (reference_type, reference_id) partiel (anti-double écriture)

### `payouts`
- id, wallet_id, amount, method (bank/mm/kkiapay), status (pending/processing/executed/failed), executed_at, executed_by, gateway_ref (nullable)
- **Index** : `payouts.wallet_id`, `payouts.status`

### `financial_journal`
- id, occurred_at, reference_type/ref_id, entry_type (payment/commission/reversal/transfer/refund/adjustment), debit (nullable), credit (nullable), participant (user/vendor/driver id), balance_after, actor, status, created_at
- **Index** : `financial_journal.reference_type`, `financial_journal.reference_type+ref_id`, `financial_journal.occurred_at`

## 8. Delivery

### `delivery_zones`
- id, name, city, is_active, sort_order
- **Index** : `delivery_zones.city`, `delivery_zones.is_active`

### `delivery_rates`
- id, zone_id, vendor_id (null = global), price, effective_from, effective_to, is_active
- **Index** : `delivery_rates.zone_id`, `(zone_id, vendor_id)`

### `deliveries`
- id, order_id (unique), driver_profile_id (nullable), vendor_id, zone_id, status (enum J11: assigned/picked_up/in_delivery/delivered/cancelled), proof_code (nullable), proof_photo_path (nullable), fee (int), partner_amount (int), assigned_at, picked_up_at, delivered_at
- **Index** : `deliveries.order_id` unique, `deliveries.driver_profile_id`, `deliveries.status`

### `delivery_status_history`
- id, delivery_id, from, to, actor, reason, created_at
- **Index** : `delivery_status_history.delivery_id`

### `driver_profiles`
- id, user_id (unique), type (independent/beninfood), status (enum J10), vehicle (nullable), available (bool online/offline), last_latitude/longitude (nullable), rating
- **Index** : `driver_profiles.user_id` unique, `(status, available)`

### `driver_documents`
- id, driver_profile_id, type, file_path, status, reviewed_by/at
- **Index** : `driver_documents.driver_profile_id`

### `driver_availability_logs`
- id, driver_profile_id, was_online, to_online, changed_at
- **Index** : `driver_availability_logs.driver_profile_id`

## 9. Support

### `reviews`
- id, order_id (unique, nullable pour avis direct), user_id, product_ids (json), rating (1-5), comment, status (moderated?), created_at
- **Index** : `reviews.product` → via table d'attache ou `reviews.product_id` (alternative) ; suggéré : `review_items` (review_id, product_id)

### `complaints`
- id, user_id, order_id (nullable), type (product/delivery/payment/other), subject, description, status (open/in_progress/closed), resolution (nullable), closed_by/at
- **Index** : `complaints.user_id`, `complaints.status`

### `complaint_messages`
- id, complaint_id, sender_type (user/porteuse/system), message, created_at
- **Index** : `complaint_messages.complaint_id`

### `attachments`
- id, attachable_type/attachable_id, path, mime, size
- **Index** : `(attachable_type, attachable_id)`

## 10. Notifications & Audit

### `notifications`
- id, user_id, type (event name), title, body, data (json: type+id deep-link), read_at, created_at
- **Index** : `notifications.user_id`, `(user_id, read_at)`

### `notification_templates`
- id, event (unique), channel (push/email/sms), subject, body, is_active

### `audit_logs`
- id, actor_type/actor_id, action, entity_type, entity_id, changes (json), ip, user_agent, created_at
- **Index** : `audit_logs.entity_type+entity_id`, `(actor_type, actor_id)`, `created_at`

### `webhook_events`
- id, gateway, event_type, payload (json), signature, received_at, processed_at, status (received/processed/ignored/failed), error (nullable)
- **Index** : `webhook_events.gateway_txn_id` unique partiel → via payload, `(gateway, status)`

### `system_logs`
- id, level, channel, message, context (json), created_at

## 11. Règles d'index globales

1. **Index sur toutes les FK** utilisées en filtre/join.
2. **Index uniques** pour protéger l'intégrité (user_devices.fcm_token, order reference, payments.gateway_txn_id, order_financials.order_id…).
3. **Index composés** alignés sur les queries de listing (user+status, zone+vendor, etc.).
4. Éviter les index sur les champs faiblement cardinaux seuls (ex. `status`) sauf si nécessité ; favoriser les index composés.
5. Les tables **append-only** (journal_financier, historiques) n'ont pas d'UPDATE père — index orientation lecture/rapports.

## 12. Critères d'acceptation

- [ ] Liste exhaustive des tables (avec `user_roles` et `user_devices`)
- [ ] Index recommandés pour chaque table
- [ ] Contraintes d'unicité clés identifiées
- [ ] Prêt pour la rédaction des migrations (Phase 05)