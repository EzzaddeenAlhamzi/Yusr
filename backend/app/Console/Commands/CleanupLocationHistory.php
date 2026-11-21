<?php

namespace App\Console\Commands;

use App\Services\LocationHistoryCleanupService;
use Illuminate\Console\Command;

/**
 * P2.4-A — purge location_tracking rows older than 7 days.
 */
class CleanupLocationHistory extends Command
{
    protected $signature = 'location:cleanup-history';

    protected $description = 'P2.4 — delete location_tracking rows older than 7 days';

    public function handle(LocationHistoryCleanupService $service): int
    {
        $result = $service->cleanup();
        $this->info('Deleted '.$result['deleted'].' rows older than '.$result['cutoff']);

        return self::SUCCESS;
    }
}
