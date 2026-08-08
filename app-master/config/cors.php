<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS) Configuration
    |--------------------------------------------------------------------------
    |
    | Here you may configure your settings for cross-origin resource sharing
    | or "CORS". This determines what cross-origin operations may execute
    | in web browsers. You are free to adjust these settings as needed.
    |
    | To learn more: https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    // Seules les méthodes réellement exposées par l'API (cf. routes/api.php).
    'allowed_methods' => ['GET', 'POST'],

    // Liste blanche d'origines via env (CSV). Vide par défaut : l'API est
    // consommée en same-origin, donc aucune origine tierce n'est autorisée.
    // Ex. : CORS_ALLOWED_ORIGINS="https://app.kubequest.local"
    'allowed_origins' => array_filter(
        explode(',', (string) env('CORS_ALLOWED_ORIGINS', ''))
    ),

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['Content-Type', 'X-Requested-With', 'Accept', 'Origin'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
