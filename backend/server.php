<?php

use Illuminate\Foundation\Application;
use Illuminate\Http\Request;

// Routeur de développement (option « Router PHP dev »).
// Usage : php -S 0.0.0.0:8000 server.php
//
// Sert les fichiers statiques de public/ (y compris public/storage -> storage/app/public)
// avec les en-têtes CORS nécessaires pour la web app (Flutter web / navigateur),
// puis renvoie les autres requêtes vers Laravel.

$corsHeaders = [
    'Access-Control-Allow-Origin' => '*',
    'Access-Control-Allow-Methods' => 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers' => 'Content-Type, Accept, Authorization, X-Requested-With, X-XSRF-TOKEN',
    'Access-Control-Max-Age' => '86400',
];

foreach ($corsHeaders as $name => $value) {
    header($name.': '.$value);
}

$uri = urldecode(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));

// CORS pour les requêtes OPTIONS (pré-vol d'un navigateur).
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);

    return true;
}

$file = __DIR__.'/public'.$uri;

if ($uri !== '/' && is_file($file)) {
    $types = [
        'svg' => 'image/svg+xml',
        'webp' => 'image/webp',
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'css' => 'text/css',
        'js' => 'application/javascript',
        'json' => 'application/json',
        'woff2' => 'font/woff2',
        'woff' => 'font/woff',
        'ttf' => 'font/ttf',
        'html' => 'text/html',
        'txt' => 'text/plain',
    ];

    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    header('Content-Type: '.($types[$ext] ?? mime_content_type($file) ?: 'application/octet-stream'));

    readfile($file);

    return true;
}

require __DIR__.'/vendor/autoload.php';

/** @var Application $app */
$app = require __DIR__.'/bootstrap/app.php';

$app->handleRequest(Request::capture());
