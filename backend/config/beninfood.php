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
    | Deadlines métier (minutes / secondes)
    |--------------------------------------------------------------------------
    */
    'orders' => [
        'payment_deadline_minutes' => (int) env('BENINFOOD_PAYMENT_DEADLINE_MINUTES', 15),
        'vendor_acceptance_minutes' => (int) env('BENINFOOD_VENDOR_ACCEPTANCE_MINUTES', 5),
        'client_withdrawal_minutes' => (int) env('BENINFOOD_CLIENT_WITHDRAWAL_MINUTES', 10),
        'driver_offer_seconds' => (int) env('BENINFOOD_DRIVER_OFFER_SECONDS', 60),
        'driver_acceptance_seconds' => (int) env('BENINFOOD_DRIVER_ACCEPTANCE_SECONDS', 45),
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
