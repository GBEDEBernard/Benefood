<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Livreur visé pour une commande (choix client/vendeur) et livraison ciblée
     * pour une course ou un colis : l'offre reste à accepter par ce livreur.
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->uuid('preferred_driver_profile_id')->nullable()->after('zone_id')->index();
        });

        Schema::table('deliveries', function (Blueprint $table) {
            $table->uuid('targeted_driver_profile_id')->nullable()->after('driver_profile_id')->index();
        });

        Schema::table('parcels', function (Blueprint $table) {
            $table->uuid('targeted_driver_profile_id')->nullable()->after('driver_profile_id')->index();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('preferred_driver_profile_id');
        });

        Schema::table('deliveries', function (Blueprint $table) {
            $table->dropColumn('targeted_driver_profile_id');
        });

        Schema::table('parcels', function (Blueprint $table) {
            $table->dropColumn('targeted_driver_profile_id');
        });
    }
};
