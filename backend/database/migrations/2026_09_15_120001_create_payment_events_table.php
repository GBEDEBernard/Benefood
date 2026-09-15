<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('payment_events')) {
            Schema::create('payment_events', function (Blueprint $table) {
            $table->id();
            $table->string('provider')->index();
            $table->string('provider_transaction_id')->index();
            $table->json('payload')->nullable();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();

            $table->unique(['provider', 'provider_transaction_id']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_events');
    }
};
