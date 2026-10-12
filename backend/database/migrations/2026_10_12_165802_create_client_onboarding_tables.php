<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('client_profiles', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->unique()->constrained('users');
            $table->string('status', 20)->default('pending')->index();
            $table->string('full_name')->nullable();
            $table->string('phone', 20)->nullable();
            $table->string('address')->nullable();
            $table->string('city')->nullable();
            $table->timestamps();
        });

        Schema::create('client_documents', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('client_profile_id')->constrained('client_profiles')->cascadeOnDelete();
            $table->string('type', 50);
            $table->string('file_path');
            $table->string('status', 20)->default('submitted');
            $table->foreignUuid('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->string('reason')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('client_documents');
        Schema::dropIfExists('client_profiles');
    }
};
