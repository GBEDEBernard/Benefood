<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\ParcelStatus;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Parcel;
use App\Models\Review;
use App\Support\StatsPeriod;
use Illuminate\Support\Carbon;

class DriverStatsService
{
    public function forDriver(DriverProfile $driver, ?string $period = '30d'): array
    {
        $period = StatsPeriod::resolve($period);
        $from = $period->from;
        $to = $period->to;
        [$previousFrom, $previousTo] = $period->previous();

        $delivered = DeliveryStatus::Delivered->value;
        $deliveryCancelled = DeliveryStatus::Cancelled->value;
        $parcelDelivered = ParcelStatus::Delivered->value;
        $parcelCancelled = ParcelStatus::Cancelled->value;

        $deliveries = fn (Carbon $start, Carbon $end) => Delivery::query()
            ->where('driver_profile_id', $driver->id)
            ->where('status', $delivered)
            ->whereBetween('delivered_at', [$start, $end]);

        $parcels = fn (Carbon $start, Carbon $end) => Parcel::query()
            ->where('driver_profile_id', $driver->id)
            ->where('status', $parcelDelivered)
            ->whereBetween('delivered_at', [$start, $end]);

        $ordersDelivered = (int) $deliveries($from, $to)->count();
        $parcelsDelivered = (int) $parcels($from, $to)->count();
        $missionsCompleted = $ordersDelivered + $parcelsDelivered;

        $missionsCancelled = (int) Delivery::query()
            ->where('driver_profile_id', $driver->id)
            ->where('status', $deliveryCancelled)
            ->whereBetween('created_at', [$from, $to])
            ->count()
            + (int) Parcel::query()
                ->where('driver_profile_id', $driver->id)
                ->where('status', $parcelCancelled)
                ->whereBetween('created_at', [$from, $to])
                ->count();

        $ordersEarnings = (int) $deliveries($from, $to)->sum('partner_amount');
        $parcelsEarnings = (int) $parcels($from, $to)->sum('partner_amount');
        $earnings = $ordersEarnings + $parcelsEarnings;

        $previousEarnings = (int) $deliveries($previousFrom, $previousTo)->sum('partner_amount')
            + (int) $parcels($previousFrom, $previousTo)->sum('partner_amount');
        $previousMissions = (int) $deliveries($previousFrom, $previousTo)->count()
            + (int) $parcels($previousFrom, $previousTo)->count();

        $distanceKm = (float) $parcels($from, $to)->sum('distance_km');
        $attempted = $missionsCompleted + $missionsCancelled;

        return [
            'period' => $period->toArray(),
            'currency' => 'XOF',
            'kpis' => [
                'missions_completed' => $missionsCompleted,
                'orders_delivered' => $ordersDelivered,
                'parcels_delivered' => $parcelsDelivered,
                'missions_cancelled' => $missionsCancelled,
                'completion_rate' => $attempted > 0 ? round($missionsCompleted / $attempted * 100, 1) : 0.0,
                'earnings' => $earnings,
                'orders_earnings' => $ordersEarnings,
                'parcels_earnings' => $parcelsEarnings,
                'average_per_mission' => $missionsCompleted > 0 ? intdiv($earnings, $missionsCompleted) : 0,
                'distance_km' => round($distanceKm, 1),
                'rating' => $this->rating($driver, $from, $to),
            ],
            'comparison' => [
                'earnings_pct' => $this->change($earnings, $previousEarnings),
                'missions_pct' => $this->change($missionsCompleted, $previousMissions),
            ],
            'series' => $this->series($deliveries($from, $to), $parcels($from, $to), $period),
            'breakdown' => [
                ['type' => 'orders', 'count' => $ordersDelivered, 'earnings' => $ordersEarnings],
                ['type' => 'parcels', 'count' => $parcelsDelivered, 'earnings' => $parcelsEarnings],
            ],
            'recent' => $this->recent($driver),
        ];
    }

    private function series($deliveriesQuery, $parcelsQuery, StatsPeriod $period): array
    {
        $buckets = [];
        foreach ($period->buckets() as $key) {
            $buckets[$key] = ['label' => $key, 'earnings' => 0, 'missions' => 0];
        }

        foreach ($deliveriesQuery->get(['delivered_at', 'partner_amount']) as $delivery) {
            $date = $delivery->delivered_at;
            if ($date === null) {
                continue;
            }
            $key = $period->bucketKey($date);
            if (! isset($buckets[$key])) {
                continue;
            }
            $buckets[$key]['earnings'] += (int) $delivery->partner_amount;
            $buckets[$key]['missions']++;
        }

        foreach ($parcelsQuery->get(['delivered_at', 'partner_amount']) as $parcel) {
            $date = $parcel->delivered_at;
            if ($date === null) {
                continue;
            }
            $key = $period->bucketKey($date);
            if (! isset($buckets[$key])) {
                continue;
            }
            $buckets[$key]['earnings'] += (int) $parcel->partner_amount;
            $buckets[$key]['missions']++;
        }

        return array_values($buckets);
    }

    private function recent(DriverProfile $driver): array
    {
        $deliveries = Delivery::query()
            ->with('order:id,reference')
            ->where('driver_profile_id', $driver->id)
            ->whereNotNull('delivered_at')
            ->orderByDesc('delivered_at')
            ->limit(5)
            ->get()
            ->map(fn (Delivery $delivery) => [
                'id' => (string) $delivery->id,
                'type' => 'order',
                'label' => $delivery->order?->reference ? 'Commande '.$delivery->order->reference : 'Commande',
                'delivered_at' => $delivery->delivered_at?->toIso8601String(),
                'earnings' => (int) $delivery->partner_amount,
            ]);

        $parcels = Parcel::query()
            ->where('driver_profile_id', $driver->id)
            ->whereNotNull('delivered_at')
            ->orderByDesc('delivered_at')
            ->limit(5)
            ->get()
            ->map(fn (Parcel $parcel) => [
                'id' => (string) $parcel->id,
                'type' => 'parcel',
                'label' => $parcel->tracking_code ? 'Colis '.$parcel->tracking_code : 'Colis',
                'delivered_at' => $parcel->delivered_at?->toIso8601String(),
                'earnings' => (int) $parcel->partner_amount,
            ]);

        $all = $deliveries->concat($parcels)->sortByDesc('delivered_at')->take(5)->values();

        return $all->all();
    }

    private function rating(DriverProfile $driver, Carbon $from, Carbon $to): array
    {
        $base = Review::query()
            ->where('driver_profile_id', $driver->id)
            ->whereNotNull('driver_rating')
            ->whereBetween('created_at', [$from, $to]);

        $count = (int) (clone $base)->count();
        $average = (clone $base)->avg('driver_rating');

        return [
            'average' => $average !== null ? round((float) $average, 1) : null,
            'count' => $count,
        ];
    }

    private function change(int|float $current, int|float $previous): ?float
    {
        if ($previous <= 0) {
            return $current > 0 ? 100.0 : null;
        }

        return round((($current - $previous) / $previous) * 100, 1);
    }
}
