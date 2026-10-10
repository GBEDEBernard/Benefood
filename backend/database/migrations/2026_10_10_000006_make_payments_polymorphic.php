<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cahier de conception v1.0 — paiement des colis.
 *
 * La table `payments` était liée à une commande ; on la rend polymorphe pour
 * couvrir aussi les colis (order_id nullable + parcel_id).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->uuid('order_id')->nullable()->change();
            $table->foreignUuid('parcel_id')->nullable()->after('order_id')->constrained('parcels')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('parcel_id');
        });
    }
};
