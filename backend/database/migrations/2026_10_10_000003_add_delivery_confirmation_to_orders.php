<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cahier de conception v1.0 — confirmation de livraison.
 *
 * À la livraison, les soldes restent en attente (séquestre) jusqu'à la
 * confirmation du client ou, à défaut, la confirmation automatique après un
 * délai (30 min par défaut).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->timestamp('delivery_confirmed_at')->nullable()->after('delivered_at');
            $table->timestamp('auto_confirm_at')->nullable()->after('delivery_confirmed_at');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['delivery_confirmed_at', 'auto_confirm_at']);
        });
    }
};
