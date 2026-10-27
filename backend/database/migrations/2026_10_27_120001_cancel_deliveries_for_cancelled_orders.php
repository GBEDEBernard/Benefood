<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        $orderIds = DB::table('orders')
            ->whereIn('status', ['cancelled', 'refunded'])
            ->pluck('id');

        if ($orderIds->isEmpty()) {
            return;
        }

        $now = now();

        $deliveries = DB::table('deliveries')
            ->whereIn('order_id', $orderIds)
            ->where('status', '!=', 'delivered')
            ->get(['id', 'status']);

        foreach ($deliveries as $delivery) {
            $updates = [
                'targeted_driver_profile_id' => null,
                'updated_at' => $now,
            ];

            if ($delivery->status !== 'cancelled') {
                $updates['status'] = 'cancelled';

                DB::table('delivery_status_history')->insert([
                    'id' => (string) Str::uuid(),
                    'delivery_id' => $delivery->id,
                    'from_status' => $delivery->status,
                    'to_status' => 'cancelled',
                    'actor' => 'system',
                    'reason' => 'Commande annulée — réparation automatique',
                    'created_at' => $now,
                ]);
            }

            DB::table('deliveries')->where('id', $delivery->id)->update($updates);
        }

        if (Schema::hasTable('delivery_assignments')) {
            DB::table('delivery_assignments')
                ->whereIn('order_id', $orderIds)
                ->whereIn('status', ['active', 'pending_handover'])
                ->update([
                    'status' => 'cancelled',
                    'completed_at' => $now,
                    'updated_at' => $now,
                ]);
        }

        if (Schema::hasTable('delivery_reassignment_requests')) {
            DB::table('delivery_reassignment_requests')
                ->whereIn('order_id', $orderIds)
                ->where('status', 'pending')
                ->update([
                    'status' => 'cancelled',
                    'completed_at' => $now,
                    'updated_at' => $now,
                ]);
        }
    }

    public function down(): void
    {
        // Réparation de données : aucune restauration automatique.
    }
};
