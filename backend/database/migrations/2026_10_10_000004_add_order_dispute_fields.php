<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cahier de conception v1.0 — statut « en litige ».
 *
 * Le client ou l'administrateur peut ouvrir un litige : les soldes en attente
 * restent bloqués jusqu'à la décision de la porteuse (libération ou remboursement).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->timestamp('disputed_at')->nullable()->after('delivered_at');
            $table->string('dispute_reason')->nullable()->after('disputed_at');
            $table->string('dispute_resolution')->nullable()->after('dispute_reason');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['disputed_at', 'dispute_reason', 'dispute_resolution']);
        });
    }
};
