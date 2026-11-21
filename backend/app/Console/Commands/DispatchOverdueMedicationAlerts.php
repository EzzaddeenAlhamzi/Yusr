<?php

namespace App\Console\Commands;

use App\Services\CaregiverOverdueAlertService;
use Carbon\Carbon;
use Illuminate\Console\Command;

class DispatchOverdueMedicationAlerts extends Command
{
    protected $signature = 'notifications:dispatch-overdue-med-alerts {--now=}';

    protected $description = 'P2.3 Channel B: create idempotent caregiver in-app alerts for overdue unconfirmed doses';

    public function handle(CaregiverOverdueAlertService $service): int
    {
        $nowOpt = $this->option('now');
        $now = $nowOpt ? Carbon::parse($nowOpt) : Carbon::now();

        $result = $service->dispatch($now);
        $this->info(sprintf(
            'overdue_alerts created=%d skipped=%d candidates=%d',
            $result['created'],
            $result['skipped'],
            $result['candidates']
        ));

        return self::SUCCESS;
    }
}
