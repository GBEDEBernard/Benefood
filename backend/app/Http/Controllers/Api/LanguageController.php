<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\Api;
use Illuminate\Http\JsonResponse;

/**
 * Référentiel public des langues proposées par l'application.
 *
 * Les codes correspondent à la colonne `users.locale` et aux préférences
 * vendeur. « fon » est la langue nationale du Bénin (fɔngbè).
 */
class LanguageController extends Controller
{
    public function index(): JsonResponse
    {
        return Api::ok([
            [
                'code' => 'fr',
                'name' => 'Français',
                'native_name' => 'Français',
                'is_default' => true,
            ],
            [
                'code' => 'en',
                'name' => 'Anglais',
                'native_name' => 'English',
                'is_default' => false,
            ],
            [
                'code' => 'fon',
                'name' => 'Fon',
                'native_name' => 'Fɔngbè',
                'is_default' => false,
            ],
        ]);
    }
}
