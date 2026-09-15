# Intégration Kkiapay — Guide rapide

Objectif: fournir un schéma d'intégration côté client (mobile/web) et côté serveur (Laravel) en sandbox, avec bonnes pratiques de sécurité.

1) Configuration

- Ajouter dans `.env` (backend):

```
KKIAPAY_KEY=42bce450b10e11f194f6bb659edc43c1
KKIAPAY_SANDBOX=true
KKIAPAY_WEBHOOK_SECRET=
```

- Le fichier de configuration `config/kkiapay.php` lit ces variables.

2) Côté client (web) — Widget JavaScript

- Inclure le script avant `</body>`:

```html
<script src="https://cdn.kkiapay.me/k.js"></script>
```

- Exemple de bouton (le serveur doit renvoyer `amount` et `key` valides) :

```html
<kkiapay-widget amount="1" key="42bce450b10e11f194f6bb659edc43c1" callback="https://votre-backend.example/payments/callback" />
```

3) Côté Android

- Ajouter la dépendance dans `build.gradle`:

```
implementation 'co.opensi.kkiapay:kkiapay:1.1.8'
```

- Initialiser dans la classe `Application` :

```java
Kkiapay.init(applicationContext, "<kkiapay-api-key>", SdkConfig(themeColor = R.color.colorPrimary, imageResource = R.raw.logo));
```

4) Flow serveur (Laravel)

- Endpoints ajoutés dans `routes/api_v1.php` :
  - `POST /api/v1/payments/create` (auth) — crée session de paiement pour une `order_id` (recalcule montant côté serveur)
  - `POST /api/v1/payments/verify` (auth) — vérifie une transaction via l'API Kkiapay
  - `POST /api/v1/payments/webhook` (public) — reçoit notifications provider

- Fichiers ajoutés:
  - `app/Services/Payments/PaymentGateway.php` — interface
  - `app/Services/Payments/KkiapayConnector.php` — connecteur sandbox
  - `app/Http/Controllers/Api/PaymentController.php` — endpoints create/verify/webhook

5) Sécurité et bonnes pratiques

- Ne jamais faire confiance au montant envoyé par le client : recalculer le sous-total, frais et total côté serveur (déjà prévu dans `KkiapayConnector::createPayment`).
- Vérifier que l'utilisateur a le droit d'initier le paiement pour la commande (ownership + statut).
- Webhook: vérifier signature (si `KKIAPAY_WEBHOOK_SECRET` disponible) et appliquer idempotence (table `payment_events` ou colonne `payment_status` sur `orders`).
- Marquer les états de paiement de façon atomique et lier aux écritures financières (transactions/ledger) dans une transaction DB.
- Protéger contre le replay: stocker l'`id` de la transaction provider et ignorer les doublons.

6) Étapes suivantes proposées (je peux implémenter):

- Vérification serveur complète via l'API Kkiapay (endpoints d'authentification si nécessaires).
- Webhook signature verification + idempotency table et migration.
- Liaison automatique du paiement à la `Order` et écriture en comptabilité (table `payments` / `transactions`).
- UI client pour lancer le widget à partir du payload renvoyé par `/payments/create`.
