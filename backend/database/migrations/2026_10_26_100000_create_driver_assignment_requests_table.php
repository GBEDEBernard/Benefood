<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Demande explicite d'un client à un livreur proche pour une commande ou
     * un colis. Une seule demande active par commande/colis ; l'acceptation
     * passe ensuite par le flux de course existant.
     */
    public function up(): void
    {
        Schema::create('driver_assignment_requests', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('assignable_type');
            $table->uuid('assignable_id');
            $table->foreignUuid('client_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('driver_profile_id')->constrained('driver_profiles')->cascadeOnDelete();
            $table->string('status', 20)->default('pending');
            $table->timestamp('offered_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('responded_at')->nullable();
            $table->string('refusal_reason', 500)->nullable();
            $table->timestamps();

            $table->index(['assignable_type', 'assignable_id']);
            $table->index(['driver_profile_id', 'status']);
            $table->index(['status', 'expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('driver_assignment_requests');
    }
};
