<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Livreurs favoris d'un client ou d'une boutique (avec accord du livreur).
     */
    public function up(): void
    {
        Schema::create('favorite_drivers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('owner_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('driver_profile_id')->constrained('driver_profiles')->cascadeOnDelete();
            $table->string('status')->default('pending');
            $table->timestamp('requested_at')->nullable();
            $table->timestamp('responded_at')->nullable();
            $table->timestamps();

            $table->unique(['owner_user_id', 'driver_profile_id']);
            $table->index('driver_profile_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('favorite_drivers');
    }
};
