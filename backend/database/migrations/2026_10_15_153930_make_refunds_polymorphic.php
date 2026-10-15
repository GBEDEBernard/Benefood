<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Remboursements : un remboursement peut viser une commande ou un colis
     * (J120/J121). L'annulation d'un colis payé en ligne doit pouvoir être
     * remboursée via la même mécanique que les commandes.
     */
    public function up(): void
    {
        Schema::table('refunds', function (Blueprint $table) {
            $table->uuid('order_id')->nullable()->change();
            $table->foreignUuid('parcel_id')->nullable()->after('order_id')->constrained('parcels')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('refunds', function (Blueprint $table) {
            $table->dropConstrainedForeignId('parcel_id');
        });
    }
};
