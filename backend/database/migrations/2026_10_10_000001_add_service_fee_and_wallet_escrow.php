<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cahier de conception v1.0 — répartition financière :
 * - frais de service client (5 %) et commission livreur (20 %) figés par commande ;
 * - wallets scindés en « solde en attente » (séquestre) et « solde disponible ».
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('order_financials', function (Blueprint $table) {
            $table->unsignedInteger('service_fee')->default(0)->after('delivery_fee');
            $table->unsignedInteger('delivery_commission_rate')->default(0)->after('delivery_partner_amount');
            $table->unsignedInteger('delivery_commission_amount')->default(0)->after('delivery_commission_rate');
        });

        Schema::table('wallets', function (Blueprint $table) {
            $table->unsignedInteger('pending_balance')->default(0)->after('balance');
            $table->unsignedInteger('available_balance')->default(0)->after('pending_balance');
        });
    }

    public function down(): void
    {
        Schema::table('order_financials', function (Blueprint $table) {
            $table->dropColumn(['service_fee', 'delivery_commission_rate', 'delivery_commission_amount']);
        });

        Schema::table('wallets', function (Blueprint $table) {
            $table->dropColumn(['pending_balance', 'available_balance']);
        });
    }
};
