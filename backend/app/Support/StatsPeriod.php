<?php

namespace App\Support;

use Illuminate\Support\Carbon;

/**
 * Bornes et granularité d'une période d'analyse de tableau de bord
 * (`7d`, `30d`, `90d`, `12m`). Sert à la fois au vendeur et au livreur.
 */
final class StatsPeriod
{
    /** @var list<string> */
    public const KEYS = ['7d', '30d', '90d', '12m'];

    private function __construct(
        public readonly string $key,
        public readonly Carbon $from,
        public readonly Carbon $to,
        public readonly string $granularity,
    ) {}

    public static function resolve(?string $period): self
    {
        $period = in_array($period, self::KEYS, true) ? $period : '30d';
        $now = Carbon::now();

        [$from, $to, $granularity] = match ($period) {
            '7d' => [$now->copy()->subDays(6)->startOfDay(), $now->copy()->endOfDay(), 'day'],
            '90d' => [$now->copy()->subDays(89)->startOfDay(), $now->copy()->endOfDay(), 'day'],
            '12m' => [$now->copy()->subMonths(11)->startOfMonth(), $now->copy()->endOfMonth(), 'month'],
            default => [$now->copy()->subDays(29)->startOfDay(), $now->copy()->endOfDay(), 'day'],
        };

        return new self($period, $from, $to, $granularity);
    }

    /**
     * Période équivalente immédiatement précédente (pour la comparaison).
     *
     * @return array{0: Carbon, 1: Carbon}
     */
    public function previous(): array
    {
        $length = $this->from->diffInSeconds($this->to);

        return [$this->from->copy()->subSeconds($length + 1), $this->from->copy()->subSecond()];
    }

    public function bucketKey(Carbon $date): string
    {
        return $this->granularity === 'month'
            ? $date->format('Y-m')
            : $date->format('Y-m-d');
    }

    /**
     * Clés des buckets de la période, dans l'ordre chronologique.
     *
     * @return list<string>
     */
    public function buckets(): array
    {
        $buckets = [];
        $cursor = $this->granularity === 'month'
            ? $this->from->copy()->startOfMonth()
            : $this->from->copy()->startOfDay();
        $last = $this->granularity === 'month'
            ? $this->to->copy()->startOfMonth()
            : $this->to->copy()->startOfDay();

        while ($cursor->lessThanOrEqualTo($last)) {
            $buckets[] = $this->bucketKey($cursor);
            $cursor = $this->granularity === 'month'
                ? $cursor->copy()->addMonth()
                : $cursor->copy()->addDay();
        }

        return $buckets;
    }

    /**
     * @return array{key: string, from: string, to: string, granularity: string}
     */
    public function toArray(): array
    {
        return [
            'key' => $this->key,
            'from' => $this->from->toDateString(),
            'to' => $this->to->toDateString(),
            'granularity' => $this->granularity,
        ];
    }
}
