<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payment_events', function (Blueprint $table) {
            $table->string('provider', 30)->default('kkiapay')->after('event_type');
            $table->string('provider_transaction_id')->nullable()->after('provider');
            $table->timestamp('processed_at')->nullable()->after('payload');
        });

        DB::statement('UPDATE payment_events SET provider = event_type WHERE provider = "kkiapay"');

        Schema::table('payment_events', function (Blueprint $table) {
            $table->unique(['provider', 'provider_transaction_id']);
        });

        Schema::table('payment_events', function (Blueprint $table) {
            $table->foreignUuid('payment_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('payment_events', function (Blueprint $table) {
            $table->dropIndex(['provider', 'provider_transaction_id']);
            $table->dropColumn(['provider', 'provider_transaction_id', 'processed_at']);
        });
    }
};
