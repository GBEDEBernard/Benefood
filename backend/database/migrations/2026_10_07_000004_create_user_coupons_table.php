<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Coupons/promos attribués à un client (J153 — stats et section Coupons).
     */
    public function up(): void
    {
        Schema::create('user_coupons', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('code', 32);
            $table->string('label');
            $table->string('discount_type', 20)->default('percent');
            $table->unsignedBigInteger('discount_value')->default(0);
            $table->unsignedBigInteger('min_amount')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('used_at')->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'code']);
            $table->index(['user_id', 'used_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_coupons');
    }
};
