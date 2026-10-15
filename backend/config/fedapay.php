<?php

return [
    /*
    |--------------------------------------------------------------------------
    | FedaPay — passerelle de paiement (encaissement & retraits)
    |--------------------------------------------------------------------------
    | `sandbox` bascule l'API entre l'environnement de test et la production.
    | `secret_key` (sk_...) authentifie les appels serveur ; la clé publique
    | (pk_...) n'est utilisée que côté client (Checkout.js / WebView).
    | `webhook_secret` (wh_...) vérifie la signature X-FEDAPAY-SIGNATURE.
    */
    'enabled' => (bool) env('FEDAPAY_ENABLED', true),
    'sandbox' => (bool) env('FEDAPAY_SANDBOX', true),
    'api_base' => env('FEDAPAY_BASE_URL'),
    'public_key' => env('FEDAPAY_PUBLIC_KEY'),
    'secret_key' => env('FEDAPAY_SECRET_KEY'),
    'webhook_secret' => env('FEDAPAY_WEBHOOK_SECRET'),
    'currency' => env('FEDAPAY_CURRENCY', 'XOF'),
    'merchant_country' => env('FEDAPAY_MERCHANT_COUNTRY', 'bj'),
    'default_payout_mode' => env('FEDAPAY_DEFAULT_PAYOUT_MODE', 'mtn_open'),
];
