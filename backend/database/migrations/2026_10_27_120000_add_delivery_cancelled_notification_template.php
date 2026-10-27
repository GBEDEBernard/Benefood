<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        $exists = DB::table('notification_templates')
            ->where('event', 'delivery.cancelled')
            ->where('channel', 'push')
            ->exists();

        if ($exists) {
            return;
        }

        $now = now();

        DB::table('notification_templates')->insert([
            'id' => (string) Str::uuid(),
            'event' => 'delivery.cancelled',
            'channel' => 'push',
            'subject' => 'Course annulée',
            'body' => 'La course #{reference} a été annulée. Vous êtes de nouveau disponible pour d\'autres missions.',
            'is_active' => true,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    public function down(): void
    {
        DB::table('notification_templates')
            ->where('event', 'delivery.cancelled')
            ->where('channel', 'push')
            ->delete();
    }
};
