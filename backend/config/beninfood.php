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
    | Tous les montants sont stockés en XOF entiers (FCFA, sans décimales).
    */
    'currency' => env('BENINFOOD_CURRENCY', 'XOF'),
    'currency_precision' => 0,
    // Parité fixe du franc CFA : 1 EUR = 655,957 XOF. Utilisée uniquement
    // pour l'affichage indicatif en euros (les débits restent en XOF).
    'eur_rate' => (float) env('BENINFOOD_EUR_RATE', 655.957),

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
    | Tarification de la livraison selon la distance (boutique → client)
    |--------------------------------------------------------------------------
    | Le prix dépend de la distance réelle boutique → adresse client :
    | - jusqu'à `flat_km`         : prix minimum `min_fee` (ex. 2 km = 500) ;
    | - de `flat_km` à `base_km`  : progressif jusqu'à `base_fee` (ex. 8 km = 1000) ;
    | - jusqu'à `included_km`     : `base_fee` (ex. 10 km = 1000) ;
    | - au-delà de `included_km`  : +`per_km` par km (ex. 11 km = 1125, 12 km = 1250) ;
    | - au-delà de `discount_km`  : +`discounted_per_km` par km (tarif réduit).
    | Si la distance n'est pas calculable (coordonnées manquantes), on retombe
    | sur le tarif de la zone configurée, sinon `default_fee`.
    */
    'delivery_pricing' => [
        'min_fee' => (int) env('BENINFOOD_DELIVERY_MIN_FEE', 500),
        'flat_km' => (float) env('BENINFOOD_DELIVERY_FLAT_KM', 3),
        'base_km' => (float) env('BENINFOOD_DELIVERY_BASE_KM', 8),
        'base_fee' => (int) env('BENINFOOD_DELIVERY_BASE_FEE', 1000),
        'included_km' => (float) env('BENINFOOD_DELIVERY_INCLUDED_KM', 10),
        'per_km' => (int) env('BENINFOOD_DELIVERY_PER_KM', 125),
        'discount_km' => (float) env('BENINFOOD_DELIVERY_DISCOUNT_KM', 15),
        'discounted_per_km' => (int) env('BENINFOOD_DELIVERY_DISCOUNTED_PER_KM', 75),
        'default_fee' => (int) env('BENINFOOD_DELIVERY_DEFAULT_FEE', 1000),
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
    | Double authentification (cahier v1.0, sécurité back-office)
    |--------------------------------------------------------------------------
    | Rôles soumis à la double authentification OTP à chaque connexion, et
    | durée de validité (minutes) du jeton de défi émis avant validation.
    */
    'two_factor' => [
        'admin_roles' => ['porteuse', 'admin-technique'],
        'challenge_ttl_minutes' => (int) env('BENINFOOD_TWO_FACTOR_TTL_MINUTES', 10),
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
    | Calcul d'itinéraires (navigation GPS livreur / suivi client)
    |--------------------------------------------------------------------------
    | Le tracé routier est calculé côté serveur puis renvoyé à l'app sous forme
    | de polyligne. Fournisseur par défaut : Google Routes API (mode deux-roues,
    | utilisé dès que `google_key` est renseigné), sinon OSRM (routage routier
    | gratuit, sans clé), avec un repli « ligne droite » si aucun réseau.
    */
    'routing' => [
        'google_key' => env('GOOGLE_MAPS_API_KEY'),
        'google_url' => env('BENINFOOD_GOOGLE_ROUTES_URL', 'https://routes.googleapis.com/directions/v2:computeRoutes'),
        'osrm_url' => rtrim((string) env('BENINFOOD_OSRM_URL', 'https://router.project-osrm.org'), '/'),
        'timeout' => (int) env('BENINFOOD_ROUTING_TIMEOUT', 6),
        'cache_ttl' => (int) env('BENINFOOD_ROUTING_CACHE_TTL', 120),
        // Vitesse moyenne de repli (km/h) pour l'estimation « ligne droite ».
        'fallback_speed_kmh' => (int) env('BENINFOOD_ROUTING_FALLBACK_SPEED', 22),
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
