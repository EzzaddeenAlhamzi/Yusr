<?php

namespace App\Services;

/**
 * P2.4-B — Haversine geofence classification (synthetic-test friendly).
 *
 * States: UNKNOWN | INSIDE | OUTSIDE | BOUNDARY_UNCERTAIN
 * Events: ENTER | EXIT (null when no transition)
 */
class GeofenceEngine
{
    public const STATE_UNKNOWN = 'UNKNOWN';

    public const STATE_INSIDE = 'INSIDE';

    public const STATE_OUTSIDE = 'OUTSIDE';

    public const STATE_BOUNDARY_UNCERTAIN = 'BOUNDARY_UNCERTAIN';

    public const EVENT_ENTER = 'ENTER';

    public const EVENT_EXIT = 'EXIT';

    /**
     * Great-circle distance in meters.
     */
    public function haversineMeters(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earth = 6371000.0;
        $φ1 = deg2rad($lat1);
        $φ2 = deg2rad($lat2);
        $Δφ = deg2rad($lat2 - $lat1);
        $Δλ = deg2rad($lng2 - $lng1);

        $a = sin($Δφ / 2) ** 2
            + cos($φ1) * cos($φ2) * sin($Δλ / 2) ** 2;

        return 2 * $earth * asin(min(1.0, sqrt($a)));
    }

    /**
     * Classify a fix relative to a circular zone.
     * Accuracy-aware: if the accuracy circle straddles the boundary → BOUNDARY_UNCERTAIN.
     *
     * @return array{state:string,distance_m:float|null}
     */
    public function classify(
        ?float $lat,
        ?float $lng,
        ?float $accuracyMeters,
        float $centerLat,
        float $centerLng,
        float $radiusMeters
    ): array {
        if ($lat === null || $lng === null) {
            return ['state' => self::STATE_UNKNOWN, 'distance_m' => null];
        }

        if (! is_finite($lat) || ! is_finite($lng)
            || abs($lat) > 90 || abs($lng) > 180
            || $radiusMeters <= 0) {
            return ['state' => self::STATE_UNKNOWN, 'distance_m' => null];
        }

        $distance = $this->haversineMeters($lat, $lng, $centerLat, $centerLng);
        $accuracy = ($accuracyMeters !== null && $accuracyMeters >= 0)
            ? (float) $accuracyMeters
            : 0.0;

        $inner = $radiusMeters - $accuracy;
        $outer = $radiusMeters + $accuracy;

        if ($distance <= $inner) {
            return ['state' => self::STATE_INSIDE, 'distance_m' => $distance];
        }
        if ($distance >= $outer) {
            return ['state' => self::STATE_OUTSIDE, 'distance_m' => $distance];
        }

        return ['state' => self::STATE_BOUNDARY_UNCERTAIN, 'distance_m' => $distance];
    }

    /**
     * Debounced transition: BOUNDARY_UNCERTAIN never emits events.
     * UNKNOWN never falsely claims safe (no ENTER from missing GPS).
     * No duplicate EXIT/ENTER while already OUTSIDE/INSIDE.
     *
     * @return array{new_state:string,event:?string}
     */
    public function transition(?string $previousState, string $classifiedState): array
    {
        $prev = $previousState ?: self::STATE_UNKNOWN;

        if ($classifiedState === self::STATE_BOUNDARY_UNCERTAIN
            || $classifiedState === self::STATE_UNKNOWN) {
            // Hold previous decisive state when uncertain; stay UNKNOWN if never known.
            if (in_array($prev, [self::STATE_INSIDE, self::STATE_OUTSIDE], true)
                && $classifiedState === self::STATE_BOUNDARY_UNCERTAIN) {
                return ['new_state' => $prev, 'event' => null];
            }

            return ['new_state' => $classifiedState, 'event' => null];
        }

        if ($prev === $classifiedState) {
            return ['new_state' => $classifiedState, 'event' => null];
        }

        if ($classifiedState === self::STATE_INSIDE
            && in_array($prev, [self::STATE_OUTSIDE, self::STATE_UNKNOWN, self::STATE_BOUNDARY_UNCERTAIN], true)) {
            // First firm INSIDE after UNKNOWN does not auto-fire ENTER (avoid false alarm on first fix).
            if ($prev === self::STATE_OUTSIDE) {
                return ['new_state' => self::STATE_INSIDE, 'event' => self::EVENT_ENTER];
            }

            return ['new_state' => self::STATE_INSIDE, 'event' => null];
        }

        if ($classifiedState === self::STATE_OUTSIDE
            && $prev === self::STATE_INSIDE) {
            return ['new_state' => self::STATE_OUTSIDE, 'event' => self::EVENT_EXIT];
        }

        return ['new_state' => $classifiedState, 'event' => null];
    }
}
