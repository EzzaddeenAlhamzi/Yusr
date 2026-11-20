<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        // P2.3 Channel B — idempotent overdue unconfirmed → caregiver in-app alerts.
        // No FCM. Safe to re-run (unique Caregiver_ID+event_type+occurrence_key).
        $schedule->command('notifications:dispatch-overdue-med-alerts')->everyMinute();
    }

    /**
     * Register the commands for the application.
     */
    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}
