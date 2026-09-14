<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Vendeurs et cycles de vie (J29 §2).
     */
    public function up(): void
    {
        Schema::create('vendors', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->unique()->constrained('users');
            $table->string('business_name');
            $table->string('legal_name')->nullable();
            $table->string('ifu', 30)->nullable();
            $table->text('description')->nullable();
            $table->string('logo_url')->nullable();
            $table->string('cover_url')->nullable();
            $table->string('phone', 20);
            $table->string('email')->nullable();
            $table->string('city')->nullable();
            $table->text('address')->nullable();
            $table->string('status', 20)->default('pending')->index();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();
        });

        Schema::create('vendor_documents', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('vendor_id')->constrained('vendors');
            $table->string('type', 50);
            $table->string('file_path');
            $table->string('status', 20)->default('submitted')->index();
            $table->string('reason')->nullable();
            $table->foreignUuid('submitted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignUuid('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();
            $table->index('vendor_id');
        });

        Schema::create('vendor_hours', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('vendor_id')->constrained('vendors');
            $table->unsignedTinyInteger('day_of_week');
            $table->time('opens_at')->nullable();
            $table->time('closes_at')->nullable();
            $table->boolean('is_closed')->default(false);
            $table->timestamps();
            $table->unique(['vendor_id', 'day_of_week']);
        });

        Schema::create('vendor_status_history', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('vendor_id')->constrained('vendors');
            $table->string('from_status', 20)->nullable();
            $table->string('to_status', 20);
            $table->string('reason')->nullable();
            $table->string('actor_type', 30)->nullable();
            $table->uuid('actor_id')->nullable();
            $table->timestamp('created_at')->nullable();
            $table->index('vendor_id');
            $table->index('actor_id');
        });

        Schema::create('vendor_settings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('vendor_id')->unique()->constrained('vendors');
            $table->unsignedInteger('commission_exception_rate')->nullable();
            $table->unsignedInteger('delivery_fee_share')->nullable();
            $table->unsignedInteger('max_preparation_minutes')->default(30);
            $table->boolean('auto_accept')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vendor_settings');
        Schema::dropIfExists('vendor_status_history');
        Schema::dropIfExists('vendor_hours');
        Schema::dropIfExists('vendor_documents');
        Schema::dropIfExists('vendors');
    }
};
