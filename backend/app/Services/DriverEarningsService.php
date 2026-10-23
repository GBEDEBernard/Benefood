<?php

namespace App\Services;

use App\Enums\DeliveryStatus;
use App\Enums\ParcelStatus;
use App\Models\Delivery;
use App\Models\DriverProfile;
use App\Models\Parcel;
use Illuminate\Support\Carbon;

/**
 * Agrégation des gains du livreur pour le portefeuille : aujourd'hui, cette
 * semaine et ce mois, avec les séries nécessaires aux mini-graphiques.
 *
 * Les montants proviennent des missions *livrées* (courses et colis) et de la
 * part livreur (`partner_amount`), comme le tableau de bord statistique.
 */
class DriverEarningsService
{
    /** Jours abrégés (1 = lundi … 7 = dimanche). */
    private const FR_DAYS = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    /** Mois abrégés (1 = janvier … 12 = décembre). */
    private const FR_MONTHS = [
        1 => 'Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin',
        'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc',
    ];

    /**
     * @return array<string, mixed>
     */
    public function forDriver(DriverProfile $driver): array
    {
        $now = Carbon::now();
        $entries = $this->entries(
            $driver,
            $now->copy()->subMonthsNoOverflow(5)->startOfMonth(),
            $now,
        );

        $dayStart = $now->copy()->startOfDay();
        $weekStart = $now->copy()->startOfWeek(Carbon::MONDAY);
        $monthStart = $now->copy()->startOfMonth();

        return [
            'currency' => config('beninfood.currency', 'XOF'),
            'eur_rate' => (float) config('beninfood.eur_rate', 655.957),
            'generated_at' => $now->toIso8601String(),
            'periods' => [
                'day' => $this->period(
                    $entries,
                    $dayStart,
                    $now,
                    $dayStart->copy()->subDay(),
                    $now->copy()->subDay(),
                ),
                'week' => $this->period(
                    $entries,
                    $weekStart,
                    $now,
                    $weekStart->copy()->subWeek(),
                    $now->copy()->subWeek(),
                ),
                'month' => $this->period(
                    $entries,
                    $monthStart,
                    $now,
                    $monthStart->copy()->subMonthNoOverflow(),
                    $now->copy()->subMonthNoOverflow(),
                ),
            ],
            'series' => [
                'day' => $this->dailySeries($entries, $now),
                'week' => $this->weeklySeries($entries, $now),
                'month' => $this->monthlySeries($entries, $now),
            ],
        ];
    }

    /**
     * Missions livrées sur la fenêtre, avec leur part livreur.
     *
     * @return list<array{at: Carbon, amount: int}>
     */
    private function entries(DriverProfile $driver, Carbon $from, Carbon $to): array
    {
        $deliveries = Delivery::query()
            ->where('driver_profile_id', $driver->id)
            ->where('status', DeliveryStatus::Delivered->value)
            ->whereBetween('delivered_at', [$from, $to])
            ->get(['delivered_at', 'partner_amount']);

        $parcels = Parcel::query()
            ->where('driver_profile_id', $driver->id)
            ->where('status', ParcelStatus::Delivered->value)
            ->whereBetween('delivered_at', [$from, $to])
            ->get(['delivered_at', 'partner_amount']);

        $entries = [];
        foreach ($deliveries as $delivery) {
            if ($delivery->delivered_at === null) {
                continue;
            }
            $entries[] = [
                'at' => $delivery->delivered_at->copy(),
                'amount' => (int) $delivery->partner_amount,
            ];
        }
        foreach ($parcels as $parcel) {
            if ($parcel->delivered_at === null) {
                continue;
            }
            $entries[] = [
                'at' => $parcel->delivered_at->copy(),
                'amount' => (int) $parcel->partner_amount,
            ];
        }

        return $entries;
    }

    /**
     * @param  list<array{at: Carbon, amount: int}>  $entries
     * @return array{earnings: int, missions: int, comparison: float|null}
     */
    private function period(
        array $entries,
        Carbon $from,
        Carbon $to,
        Carbon $previousFrom,
        Carbon $previousTo,
    ): array {
        $current = $this->aggregate($entries, $from->timestamp, $to->timestamp);
        $previous = $this->aggregate(
            $entries,
            $previousFrom->timestamp,
            $previousTo->timestamp,
        );

        return [
            'earnings' => $current['earnings'],
            'missions' => $current['missions'],
            'comparison' => $this->change($current['earnings'], $previous['earnings']),
        ];
    }

    /**
     * @param  list<array{at: Carbon, amount: int}>  $entries
     * @return array{earnings: int, missions: int}
     */
    private function aggregate(array $entries, int $from, int $to): array
    {
        $earnings = 0;
        $missions = 0;

        foreach ($entries as $entry) {
            $timestamp = $entry['at']->timestamp;
            if ($timestamp < $from || $timestamp > $to) {
                continue;
            }
            $earnings += $entry['amount'];
            $missions++;
        }

        return ['earnings' => $earnings, 'missions' => $missions];
    }

    /**
     * @param  list<array{at: Carbon, amount: int}>  $entries
     * @return list<array{key: string, label: string, earnings: int, missions: int, current: bool}>
     */
    private function dailySeries(array $entries, Carbon $now): array
    {
        $series = [];
        for ($i = 6; $i >= 0; $i--) {
            $day = $now->copy()->subDays($i);
            $series[] = $this->bucket(
                $entries,
                $day->copy()->startOfDay()->timestamp,
                $day->copy()->endOfDay()->timestamp,
                $day->format('Y-m-d'),
                self::FR_DAYS[$day->dayOfWeekIso - 1],
                $i === 0,
            );
        }

        return $series;
    }

    /**
     * @param  list<array{at: Carbon, amount: int}>  $entries
     * @return list<array{key: string, label: string, earnings: int, missions: int, current: bool}>
     */
    private function weeklySeries(array $entries, Carbon $now): array
    {
        $series = [];
        for ($i = 3; $i >= 0; $i--) {
            $start = $now->copy()->subWeeks($i)->startOfWeek(Carbon::MONDAY);
            $end = $start->copy()->endOfWeek(Carbon::SUNDAY);

            $series[] = $this->bucket(
                $entries,
                $start->timestamp,
                $end->timestamp,
                $start->format('o-\WW'),
                $i === 0 ? 'Cette sem.' : 'Sem. '.$start->format('W'),
                $i === 0,
            );
        }

        return $series;
    }

    /**
     * @param  list<array{at: Carbon, amount: int}>  $entries
     * @return list<array{key: string, label: string, earnings: int, missions: int, current: bool}>
     */
    private function monthlySeries(array $entries, Carbon $now): array
    {
        $series = [];
        for ($i = 5; $i >= 0; $i--) {
            $start = $now->copy()->subMonthsNoOverflow($i)->startOfMonth();
            $end = $start->copy()->endOfMonth();

            $series[] = $this->bucket(
                $entries,
                $start->timestamp,
                $end->timestamp,
                $start->format('Y-m'),
                self::FR_MONTHS[(int) $start->format('n')],
                $i === 0,
            );
        }

        return $series;
    }

    /**
     * @param  list<array{at: Carbon, amount: int}>  $entries
     * @return array{key: string, label: string, earnings: int, missions: int, current: bool}
     */
    private function bucket(
        array $entries,
        int $from,
        int $to,
        string $key,
        string $label,
        bool $current,
    ): array {
        $total = $this->aggregate($entries, $from, $to);

        return [
            'key' => $key,
            'label' => $label,
            'earnings' => $total['earnings'],
            'missions' => $total['missions'],
            'current' => $current,
        ];
    }

    private function change(int $current, int $previous): ?float
    {
        if ($previous <= 0) {
            return $current > 0 ? 100.0 : null;
        }

        return round((($current - $previous) / $previous) * 100, 1);
    }
}
