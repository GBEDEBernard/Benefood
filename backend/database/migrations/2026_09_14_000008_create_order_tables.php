<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Commandes et historique de statuts (J29 §5, J30).
     */
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('reference')->unique();
            $table->foreignUuid('user_id')->constrained('users');
            $table->foreignUuid('vendor_id')->constrained('vendors');
            $table->foreignUuid('cart_id')->nullable()->unique()->constrained('carts')->nullOnDelete();
            $table->foreignUuid('zone_id')->nullable()->constrained('delivery_zones')->nullOnDelete();
            $table->string('status', 30)->default('draft')->index();
            $table->string('currency', 3)->default('XOF');
            $table->unsignedInteger('subtotal')->default(0);
            $table->unsignedInteger('discount')->default(0);
            $table->unsignedInteger('delivery_fee')->default(0);
            $table->unsignedInteger('total')->default(0);
            $table->json('address_snapshot')->nullable();
            $table->timestamp('payment_deadline_at')->nullable();
            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->string('cancellation_reason')->nullable();
            $table->uuid('cancelled_by')->nullable();
            $table->timestamps();
            $table->index('created_at');
        });

        Schema::create('order_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('order_id')->constrained('orders');
            $table->foreignUuid('product_id')->nullable()->constrained('products')->nullOnDelete();
            $table->string('name_snapshot');
            $table->unsignedInteger('unit_price_snapshot');
            $table->unsignedInteger('quantity');
            $table->unsignedInteger('subtotal');
            $table->string('variant_label')->nullable();
            $table->timestamps();
        });

        Schema::create('order_status_history', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('order_id')->constrained('orders');
            $table->string('from_status', 30)->nullable();
            $table->string('to_status', 30);
            $table->string('actor_type', 30)->nullable();
            $table->uuid('actor_id')->nullable();
            $table->string('reason')->nullable();
            $table->timestamp('created_at')->nullable();
            $table->index('actor_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_status_history');
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('orders');
    }
};
