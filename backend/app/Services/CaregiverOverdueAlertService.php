<?php

namespace App\Services;

use App\Models\Caregiver;
use App\Models\Medication;
use App\Models\MedicationDoseOccurrence;
use App\Models\Notification;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * P2.3 Channel B — idempotent in-app caregiver alerts after 30m grace.
 * Wording: overdue / not confirmed (never medical missed). No FCM.
 */
class CaregiverOverdueAlertService
{
    public const EVENT_TYPE = 'med_overdue_unconfirmed';

    public const N_TYPE = 'med_overdue';

    public function __construct(
        private readonly MedicationAdherenceService $adherence
    ) {
    }

    public function isReady(): bool
    {
        return Schema::hasTable('notifications')
            && Schema::hasTable('medication_dose_occurrences')
            && Schema::hasColumn('notifications', 'event_type')
            && Schema::hasColumn('notifications', 'occurrence_key');
    }

    /**
     * @return array{created:int,skipped:int,candidates:int}
     */
    public function dispatch(?Carbon $now = null): array
    {
        $now = $now ? $now->copy() : Carbon::now();
        $created = 0;
        $skipped = 0;

        if (! $this->isReady()) {
            return ['created' => 0, 'skipped' => 0, 'candidates' => 0];
        }

        // Portable: load recent unconfirmed rows and evaluate display state in PHP
        // using MedicationAdherenceService (MySQL + SQLite).
        $horizonStart = $now->copy()->subDays(2)->toDateString();
        $occurrences = MedicationDoseOccurrence::query()
            ->where('adherence_state', 'unconfirmed')
            ->whereDate('scheduled_date', '>=', $horizonStart)
            ->whereDate('scheduled_date', '<=', $now->toDateString())
            ->orderBy('DoseOccurrence_ID')
            ->get();

        $eligible = [];
        foreach ($occurrences as $occ) {
            if ($this->adherence->displayState($occ, $now)
                !== MedicationAdherenceService::DISPLAY_OVERDUE_NOT_CONFIRMED) {
                continue;
            }
            $eligible[] = $occ;
        }

        foreach ($eligible as $occ) {
            $caregivers = Caregiver::query()
                ->where('Eldery_ID', (int) $occ->Elderly_ID)
                ->get();

            if ($caregivers->isEmpty()) {
                $skipped++;
                continue;
            }

            $medName = Medication::query()
                ->where('Medicayion_ID', (int) $occ->Medicayion_ID)
                ->value('M_Name') ?? 'دواء';

            foreach ($caregivers as $cg) {
                if ($this->createAlertForCaregiver($cg, $occ, (string) $medName, $now)) {
                    $created++;
                } else {
                    $skipped++;
                }
            }
        }

        return [
            'created' => $created,
            'skipped' => $skipped,
            'candidates' => count($eligible),
        ];
    }

    public function createAlertForCaregiver(
        Caregiver $cg,
        MedicationDoseOccurrence $occ,
        string $medName,
        ?Carbon $now = null
    ): bool {
        $now = $now ? $now->copy() : Carbon::now();
        $cgId = (int) $cg->Caregivers_ID;
        $key = (string) $occ->occurrence_key;

        if (Notification::query()
            ->where('Caregiver_ID', $cgId)
            ->where('event_type', self::EVENT_TYPE)
            ->where('occurrence_key', $key)
            ->exists()) {
            return false;
        }

        try {
            DB::transaction(function () use ($cgId, $occ, $medName, $key, $now) {
                if (Notification::query()
                    ->where('Caregiver_ID', $cgId)
                    ->where('event_type', self::EVENT_TYPE)
                    ->where('occurrence_key', $key)
                    ->lockForUpdate()
                    ->exists()) {
                    return;
                }

                Notification::create([
                    'N_Title' => 'جرعة متأخرة — غير مؤكدة',
                    'N_Message' => 'لم يُؤكَّد تناول «'.$medName.'» بعد موعده. الحالة: متأخر / غير مؤكد (ليست دليلاً طبياً على الفوات).',
                    'N_Type' => self::N_TYPE,
                    'event_type' => self::EVENT_TYPE,
                    'occurrence_key' => $key,
                    'DoseOccurrence_ID' => (int) $occ->DoseOccurrence_ID,
                    'N_Date' => $now->format('Y-m-d'),
                    'N_Time' => $now->format('H:i:s'),
                    'N_Status' => 'غير مقروء',
                    'Caregiver_ID' => $cgId,
                    'Eldery_ID' => (int) $occ->Elderly_ID,
                ]);
            });
        } catch (\Throwable $e) {
            return false;
        }

        return Notification::query()
            ->where('Caregiver_ID', $cgId)
            ->where('event_type', self::EVENT_TYPE)
            ->where('occurrence_key', $key)
            ->exists();
    }
}
