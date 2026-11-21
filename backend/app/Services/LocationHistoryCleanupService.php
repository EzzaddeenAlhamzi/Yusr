<?php

namespace App\Services;

use App\Models\LocationTracking;
use Carbon\Carbon;
use Illuminate\Support\Facades\Schema;

/**
 * P2.4-A — retain location history for 7 days; delete older rows.
 */
class LocationHistoryCleanupService
{
    public const RETENTION_DAYS = 7;

    public function isReady(): bool
    {
        return Schema::hasTable('location_tracking');
    }

    /**
     * @return array{deleted:int,cutoff:string}
     */
    public function cleanup(?Carbon $now = null): array
    {
        $now = $now ? $now->copy() : Carbon::now();
        $cutoff = $now->copy()->subDays(self::RETENTION_DAYS);

        if (! $this->isReady()) {
            return ['deleted' => 0, 'cutoff' => $cutoff->toDateTimeString()];
        }

        $deleted = LocationTracking::query()
            ->whereNotNull('L_UpdateTime')
            ->where('L_UpdateTime', '<', $cutoff->toDateTimeString())
            ->delete();

        return [
            'deleted' => (int) $deleted,
            'cutoff' => $cutoff->toDateTimeString(),
        ];
    }
}
