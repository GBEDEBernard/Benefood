<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Mode de remise d'une commande de nourriture.
 *
 * `delivery` conserve le comportement historique (adresse, frais et livreur).
 * `pickup` signifie que le client retire sa commande chez le vendeur : aucun
 * frais de livraison, aucun livreur, montant réglé = valeur des produits.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('fulfillment_method', 16)->default('delivery')->after('payment_method');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('fulfillment_method');
        });
    }
};
