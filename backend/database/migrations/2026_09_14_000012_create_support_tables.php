<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Support : avis, réclamations, messages et pièces jointes (J29 §9).
     */
    public function up(): void
    {
        Schema::create('reviews', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('order_id')->nullable()->unique()->constrained('orders')->nullOnDelete();
            $table->foreignUuid('user_id')->constrained('users');
            $table->unsignedTinyInteger('rating');
            $table->text('comment')->nullable();
            $table->string('status', 20)->default('new');
            $table->timestamps();
        });

        Schema::create('review_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('review_id')->constrained('reviews');
            $table->foreignUuid('product_id')->constrained('products');
            $table->timestamps();
            $table->unique(['review_id', 'product_id']);
        });

        Schema::create('complaints', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users');
            $table->foreignUuid('order_id')->nullable()->constrained('orders')->nullOnDelete();
            $table->string('type', 30);
            $table->string('subject');
            $table->text('description');
            $table->string('status', 20)->default('open')->index();
            $table->text('resolution')->nullable();
            $table->foreignUuid('closed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();
        });

        Schema::create('complaint_messages', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('complaint_id')->constrained('complaints');
            $table->string('sender_type', 30);
            $table->text('message');
            $table->timestamps();
        });

        Schema::create('attachments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('attachable_type', 50);
            $table->uuid('attachable_id');
            $table->string('path');
            $table->string('mime')->nullable();
            $table->unsignedInteger('size')->nullable();
            $table->timestamps();
            $table->index(['attachable_type', 'attachable_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attachments');
        Schema::dropIfExists('complaint_messages');
        Schema::dropIfExists('complaints');
        Schema::dropIfExists('review_items');
        Schema::dropIfExists('reviews');
    }
};
