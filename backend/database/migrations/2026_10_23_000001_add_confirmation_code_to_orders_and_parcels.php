<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cahier de conception v1.0 — confirmation sécurisée par code.
 *
 * Le code est stocké chiffré (cast `encrypted`) et n'est jamais exposé au
 * livreur : seul le client (commande) ou l'expéditeur (colis) peut le lire.
 * Les fonds restent en séquestre tant que le code n'a pas été validé.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->text('confirmation_code')->nullable()->after('delivery_confirmed_at');
            $table->timestamp('confirmation_code_expires_at')->nullable()->after('confirmation_code');
            $table->unsignedTinyInteger('confirmation_code_attempts')->default(0)->after('confirmation_code_expires_at');
            $table->timestamp('confirmation_code_confirmed_at')->nullable()->after('confirmation_code_attempts');
        });

        Schema::table('parcels', function (Blueprint $table) {
            $table->text('confirmation_code')->nullable()->after('proof_code');
            $table->timestamp('confirmation_code_expires_at')->nullable()->after('confirmation_code');
            $table->unsignedTinyInteger('confirmation_code_attempts')->default(0)->after('confirmation_code_expires_at');
            $table->timestamp('confirmation_code_confirmed_at')->nullable()->after('confirmation_code_attempts');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn([
                'confirmation_code',
                'confirmation_code_expires_at',
                'confirmation_code_attempts',
                'confirmation_code_confirmed_at',
            ]);
        });

        Schema::table('parcels', function (Blueprint $table) {
            $table->dropColumn([
                'confirmation_code',
                'confirmation_code_expires_at',
                'confirmation_code_attempts',
                'confirmation_code_confirmed_at',
            ]);
        });
    }
};
