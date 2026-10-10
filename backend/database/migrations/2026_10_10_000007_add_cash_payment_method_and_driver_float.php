<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cahier de conception v1.0 — paiement à la livraison (cash).
 *
 * Les commandes ont un mode de paiement (online | cash). Pour une commande
 * cash, le livreur encaisse auprès du client et son « flottant prépayé »
 * (prepaid_balance) garantit la somme à la plateforme : celui-ci est débité
 * du montant total à la livraison, puis vendeur et livreur sont payés.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('payment_method', 20)->default('online')->after('status')->index();
        });

        Schema::table('driver_profiles', function (Blueprint $table) {
            $table->unsignedInteger('prepaid_balance')->default(0)->after('available');
        });

        Schema::create('driver_float_transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('driver_profile_id')->constrained('driver_profiles');
            $table->string('type', 10);
            $table->unsignedInteger('amount');
            $table->string('reference_type', 40)->nullable();
            $table->string('reference_id')->nullable();
            $table->string('description')->nullable();
            $table->timestamp('created_at')->nullable();
            $table->index(['driver_profile_id', 'reference_type', 'reference_id'], 'dft_driver_ref_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('driver_float_transactions');
        Schema::table('driver_profiles', function (Blueprint $table) {
            $table->dropColumn('prepaid_balance');
        });
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('payment_method');
        });
    }
};
