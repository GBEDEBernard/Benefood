<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS)
    |--------------------------------------------------------------------------
    |
    | Source unique de vérité pour les en-têtes CORS de l'API. Le middleware
    | HandleCors du framework les applique à toutes les requêtes « paths »
    | listées ci-dessous. Ne jamais renvoyer ces en-têtes manuellement depuis
    | server.php pour une requête déléguée à Laravel, sinon le navigateur
    | recevrait « Access-Control-Allow-Origin » en double et bloquerait l'appel.
    |
    */

    'paths' => ['api/*', 'storage/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['*'],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 86400,

    'supports_credentials' => false,

];
