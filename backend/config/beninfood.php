<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Version de l'API
    |--------------------------------------------------------------------------
    */
    'version' => env('BENINFOOD_VERSION', '0.1.0'),

    /*
    |--------------------------------------------------------------------------
    | Devise et précision monétaire
    |--------------------------------------------------------------------------
    | Tous les montants sont stockés en centimes XOF (entier côté serveur).
    */
    'currency' => env('BENINFOOD_CURRENCY', 'XOF'),
    'currency_precision' => 0,

    /*
    |--------------------------------------------------------------------------
    | Commission porteuse
    |--------------------------------------------------------------------------
    | Taux par défaut en pourcentage (10 = 10 %) de la base commissionnable.
    */
    'commission' => [
        'default_rate' => (int) env('BENINFOOD_COMMISSION_RATE', 10),
    ],

    /*
    |--------------------------------------------------------------------------
    | Frais de service client (cahier de conception v1.0)
    |--------------------------------------------------------------------------
    | Taux en pourcentage prélevé au client sur (nourriture + livraison).
    */
    'service_fee' => [
        'rate' => (int) env('BENINFOOD_SERVICE_FEE_RATE', 5),
    ],

    /*
    |--------------------------------------------------------------------------
    | Commission livreur
    |--------------------------------------------------------------------------
    | Taux en pourcentage prélevé par la plateforme sur le prix de livraison.
    | (Le livreur reçoit donc 80 % de la livraison.)
    */
    'delivery_commission' => [
        'rate' => (int) env('BENINFOOD_DELIVERY_COMMISSION_RATE', 20),
    ],

    /*
    |--------------------------------------------------------------------------
    | Frais de la passerelle de paiement (coût plateforme)
    |--------------------------------------------------------------------------
    | Taux en pourcentage du montant payé par le client, absorbé par la
    | plateforme. Stocké à titre informatif (non refacturé au client).
    | Le taux est exprimé en points de base (120 = 1,2 %) pour éviter les
    | problèmes de flottants.
    */
    'payment_gateway' => [
        'fee_rate_basis_points' => (int) env('BENINFOOD_GATEWAY_FEE_BASIS_POINTS', 120),
    ],

    /*
    |--------------------------------------------------------------------------
    | Envoi de colis (cahier de conception v1.0, phase 3)
    |--------------------------------------------------------------------------
    | Prix du colis selon la distance (paliers), commission plateforme et
    | tarif par défaut quand la distance n'est pas calculable.
    */
    'parcels' => [
        'commission_rate' => (int) env('BENINFOOD_PARCEL_COMMISSION_RATE', 20),
        'default_fee' => (int) env('BENINFOOD_PARCEL_DEFAULT_FEE', 1000),
        'tiers' => [
            ['max_km' => 3, 'fee' => 500],
            ['max_km' => 7, 'fee' => 1000],
            ['max_km' => null, 'fee' => 2000],
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Wallets & retraits
    |--------------------------------------------------------------------------
    | min_payout : montant minimum d'un retrait (évite les petits virements).
    */
    'wallet' => [
        'min_payout' => (int) env('BENINFOOD_WALLET_MIN_PAYOUT', 1000),
    ],

    /*
    |--------------------------------------------------------------------------
    | Deadlines métier (minutes / secondes)
    |--------------------------------------------------------------------------
    */
    'orders' => [
        'payment_deadline_minutes' => (int) env('BENINFOOD_PAYMENT_DEADLINE_MINUTES', 15),
        'vendor_acceptance_minutes' => (int) env('BENINFOOD_VENDOR_ACCEPTANCE_MINUTES', 5),
        'client_withdrawal_minutes' => (int) env('BENINFOOD_CLIENT_WITHDRAWAL_MINUTES', 10),
        'driver_offer_seconds' => (int) env('BENINFOOD_DRIVER_OFFER_SECONDS', 60),
        'driver_acceptance_seconds' => (int) env('BENINFOOD_DRIVER_ACCEPTANCE_SECONDS', 45),
        // Cahier v1.0 : sans confirmation du client, la livraison est validée
        // (et le séquestre libéré) automatiquement après ce délai.
        'delivery_auto_confirm_minutes' => (int) env('BENINFOOD_DELIVERY_AUTO_CONFIRM_MINUTES', 30),
    ],

    /*
    |--------------------------------------------------------------------------
    | Annulations (J118) : frais appliqués au remboursement selon le statut
    |--------------------------------------------------------------------------
    | Montants en centimes XOF retenus sur le remboursement lorsque l'annulation
    | intervient après le début de la préparation ou après l'affectation d'un livreur.
    */
    'cancel' => [
        'preparation_fee' => (int) env('BENINFOOD_CANCEL_PREPARATION_FEE', 1000),
        'assignment_fee' => (int) env('BENINFOOD_CANCEL_ASSIGNMENT_FEE', 500),
    ],

    /*
    |--------------------------------------------------------------------------
    | Remboursements (J120/J121)
    |--------------------------------------------------------------------------
    | automatic_execution : exécution directe via la passerelle à l'annulation,
    | sinon le remboursement reste en attente et la porteuse l'exécute manuellement.
    */
    'refunds' => [
        'automatic_execution' => (bool) env('BENINFOOD_REFUNDS_AUTOMATIC_EXECUTION', false),
    ],

    /*
    |--------------------------------------------------------------------------
    | Notifications push FCM (J126)
    |--------------------------------------------------------------------------
    | enabled : active l'envoi des push (désactivé tant que FIREBASE_CREDENTIALS
    | n'est pas fourni). Le canal « in-app » reste toujours actif.
    */
    'push' => [
        'enabled' => (bool) env('BENINFOOD_PUSH_ENABLED', false),
    ],

    /*
    |--------------------------------------------------------------------------
    | Pagination par défaut
    |--------------------------------------------------------------------------
    */
    'pagination' => [
        'per_page' => 15,
        'max_per_page' => 100,
    ],

    /*
    |--------------------------------------------------------------------------
    | Disques de stockage par domaine
    |--------------------------------------------------------------------------
    */
    'storage' => [
        'images_disk' => env('BENINFOOD_IMAGES_DISK', 'public'),
        'documents_disk' => env('BENINFOOD_DOCUMENTS_DISK', 'private'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Kkiapay (passerelle de paiement mobile money)
    |--------------------------------------------------------------------------
    */
    'kkiapay' => [
        'enabled' => (bool) env('KKIAPAY_ENABLED', false),
        'base_url' => env('KKIAPAY_BASE_URL', 'https://api.kkiapay.me'),
        'sandbox' => (bool) env('KKIAPAY_SANDBOX', true),
        'public_key' => env('KKIAPAY_PUBLIC_KEY'),
        'private_key' => env('KKIAPAY_PRIVATE_KEY'),
        'secret' => env('KKIAPAY_SECRET'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Téléphonie / internationalisation
    |--------------------------------------------------------------------------
    */
    'telephony' => [
        'default_country_code' => env('BENINFOOD_DEFAULT_COUNTRY_CODE', '229'),
    ],

];
