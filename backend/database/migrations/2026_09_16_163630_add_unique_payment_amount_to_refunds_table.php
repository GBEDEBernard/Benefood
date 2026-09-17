<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Un seul remboursement par (paiement, montant) — protection contre les
     * remboursements dupliqués pour une même annulation (J121).
     */
    public function up(): void
    {
        Schema::table('refunds', function (Blueprint $table) {
            $table->unique(['payment_id', 'amount']);
        });
    }

    public function down(): void
    {
        Schema::table('refunds', function (Blueprint $table) {
            $table->dropUnique(['payment_id', 'amount']);
        });
    }
};
