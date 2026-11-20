<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Code remis par le vendeur au livreur lors de la collecte de la commande.
 *
 * Le code est chiffré (cast `encrypted`) et n'est jamais renvoyé au livreur :
 * le vendeur le lit sur sa commande, le livreur le saisit pour prouver qu'il a
 * bien récupéré le colis avant de partir en livraison.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('deliveries', function (Blueprint $table) {
            $table->text('pickup_code')->nullable()->after('proof_photo_path');
            $table->timestamp('pickup_code_expires_at')->nullable()->after('pickup_code');
            $table->unsignedTinyInteger('pickup_code_attempts')->default(0)->after('pickup_code_expires_at');
            $table->timestamp('pickup_code_confirmed_at')->nullable()->after('pickup_code_attempts');
        });
    }

    public function down(): void
    {
        Schema::table('deliveries', function (Blueprint $table) {
            $table->dropColumn([
                'pickup_code',
                'pickup_code_expires_at',
                'pickup_code_attempts',
                'pickup_code_confirmed_at',
            ]);
        });
    }
};
