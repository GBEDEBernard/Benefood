<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * J70 — Mode d'identification de la zone : zone nommée, quartier, secteur,
     * distance (rayon autour d'un point central) ou combinaison.
     */
    public function up(): void
    {
        Schema::table('delivery_zones', function (Blueprint $table) {
            $table->string('identification_mode', 20)->default('zone')->after('name');
            $table->json('terms')->nullable()->after('city');
            $table->decimal('center_latitude', 10, 7)->nullable()->after('sort_order');
            $table->decimal('center_longitude', 10, 7)->nullable()->after('center_latitude');
            $table->decimal('radius_km', 8, 3)->nullable()->after('center_longitude');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('delivery_zones', function (Blueprint $table) {
            $table->dropColumn(['identification_mode', 'terms', 'center_latitude', 'center_longitude', 'radius_km']);
        });
    }
};
