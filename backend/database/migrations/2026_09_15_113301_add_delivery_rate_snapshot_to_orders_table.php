<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * J75 — Historise le tarif de livraison appliqué à chaque commande.
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->json('delivery_rate_snapshot')->nullable()->after('delivery_fee');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('delivery_rate_snapshot');
        });
    }
};
