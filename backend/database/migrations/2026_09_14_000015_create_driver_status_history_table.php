<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Historisation des changements de statut du compte livreur (J10 §6).
     */
    public function up(): void
    {
        Schema::create('driver_status_history', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('driver_profile_id')->constrained('driver_profiles');
            $table->string('from_status', 20)->nullable();
            $table->string('to_status', 20);
            $table->string('reason')->nullable();
            $table->string('actor_type', 30)->nullable();
            $table->uuid('actor_id')->nullable();
            $table->timestamp('created_at')->nullable();
            $table->index('driver_profile_id');
            $table->index('actor_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('driver_status_history');
    }
};
