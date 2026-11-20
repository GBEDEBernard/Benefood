<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Ajoute les références géographiques sans supprimer les anciens champs
     * libres (city, area, address_text…) encore utilisés par le code existant.
     */
    public function up(): void
    {
        Schema::table('addresses', function (Blueprint $table): void {
            $table->foreignId('country_id')->nullable()->constrained('geo_countries')->nullOnDelete();
            $table->foreignId('division_id')->nullable()->constrained('geo_divisions')->nullOnDelete();
            $table->foreignId('locality_id')->nullable()->constrained('geo_localities')->nullOnDelete();
            $table->string('address_type', 30)->default('other')->comment('home, work, other, custom');
            $table->float('gps_accuracy_m')->nullable();
            $table->string('location_source', 20)->nullable()->comment('gps, map, geocoded, manual');
            $table->index(['user_id', 'address_type']);
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->foreignId('country_id')->nullable()->constrained('geo_countries')->nullOnDelete();
            $table->foreignId('division_id')->nullable()->constrained('geo_divisions')->nullOnDelete();
            $table->foreignId('locality_id')->nullable()->constrained('geo_localities')->nullOnDelete();
            $table->float('gps_accuracy_m')->nullable();
            $table->string('location_source', 20)->nullable();
            $table->timestamp('location_recorded_at')->nullable();
        });

        Schema::table('vendors', function (Blueprint $table): void {
            $table->foreignId('country_id')->nullable()->constrained('geo_countries')->nullOnDelete();
            $table->foreignId('division_id')->nullable()->constrained('geo_divisions')->nullOnDelete();
            $table->foreignId('locality_id')->nullable()->constrained('geo_localities')->nullOnDelete();
            $table->foreignId('pickup_division_id')->nullable()->constrained('geo_divisions')->nullOnDelete();
            $table->foreignId('pickup_locality_id')->nullable()->constrained('geo_localities')->nullOnDelete();
            $table->float('gps_accuracy_m')->nullable();
            $table->float('pickup_gps_accuracy_m')->nullable();
            $table->string('location_source', 20)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('vendors', function (Blueprint $table): void {
            $table->dropColumn([
                'country_id',
                'division_id',
                'locality_id',
                'pickup_division_id',
                'pickup_locality_id',
                'gps_accuracy_m',
                'pickup_gps_accuracy_m',
                'location_source',
            ]);
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn([
                'country_id',
                'division_id',
                'locality_id',
                'gps_accuracy_m',
                'location_source',
                'location_recorded_at',
            ]);
        });

        Schema::table('addresses', function (Blueprint $table): void {
            $table->dropIndex(['user_id', 'address_type']);
            $table->dropColumn([
                'country_id',
                'division_id',
                'locality_id',
                'address_type',
                'gps_accuracy_m',
                'location_source',
            ]);
        });
    }
};
