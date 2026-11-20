<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Précision, vitesse et cap des relevés GPS pendant une mission active.
     */
    public function up(): void
    {
        Schema::table('deliveries', function (Blueprint $table): void {
            $table->decimal('last_latitude', 10, 7)->nullable();
            $table->decimal('last_longitude', 10, 7)->nullable();
            $table->timestamp('last_location_at')->nullable();
            $table->float('last_accuracy_m')->nullable();
            $table->decimal('last_heading', 5, 2)->nullable();
            $table->float('last_speed_mps')->nullable();
            $table->string('last_location_source', 20)->nullable()->comment('gps, network, manual');
            $table->index(['driver_profile_id', 'last_location_at']);
        });

        Schema::table('delivery_locations', function (Blueprint $table): void {
            $table->float('accuracy_m')->nullable();
            $table->float('speed_mps')->nullable();
            $table->string('location_source', 20)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('delivery_locations', function (Blueprint $table): void {
            $table->dropColumn(['accuracy_m', 'speed_mps', 'location_source']);
        });

        Schema::table('deliveries', function (Blueprint $table): void {
            $table->dropIndex(['driver_profile_id', 'last_location_at']);
            $table->dropColumn([
                'last_latitude',
                'last_longitude',
                'last_location_at',
                'last_accuracy_m',
                'last_heading',
                'last_speed_mps',
                'last_location_source',
            ]);
        });
    }
};
