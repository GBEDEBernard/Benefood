<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Référentiel des quartiers (villes + quartiers) utilisé pour la recherche
     * par localité et les sélecteurs d'adresse/colis.
     */
    public function up(): void
    {
        Schema::create('neighborhoods', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('city')->index();
            $table->string('name');
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->uuid('delivery_zone_id')->nullable();
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();

            $table->unique(['city', 'name']);
            $table->foreign('delivery_zone_id')
                ->references('id')
                ->on('delivery_zones')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('neighborhoods');
    }
};
