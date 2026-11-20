<?php

namespace App\Services;

use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\Medication;
use App\Models\MedicationDoseEvent;
use App\Models\MedicationDoseOccurrence;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * P2.2 medication dose adherence (A1 grace 30m, B1 online server SoT).
 *
 * Display states Upcoming/Due/OverdueNotConfirmed are computed.
 * Only taken / late_confirmed are persisted. "Missed" is never claimed medically.
 */
class MedicationAdherenceService
{
    public const GRACE_MINUTES = 30;

    /** Max inclusive days for history materialization/horizon. */
    public const MAX_HISTORY_DAYS = 14;

    public const STATE_UNCONFIRMED = 'unconfirmed';
    public const STATE_TAKEN = 'taken';
    public const STATE_LATE_CONFIRMED = 'late_confirmed';

    public const DISPLAY_UPCOMING = 'upcoming';
    public const DISPLAY_DUE = 'due';
    public const DISPLAY_OVERDUE_NOT_CONFIRMED = 'overdue_not_confirmed';
    public const DISPLAY_TAKEN = 'taken';
    public const DISPLAY_LATE_CONFIRMED = 'late_confirmed';

    public function tablesReady(): bool
    {
        return Schema::hasTable('medication_dose_occurrences')
            && Schema::hasTable('medication_dose_events');
    }

    /**
     * Infer slot + HH:MM:SS from free-text M_RepatTime (matches Flutter heuristic).
     *
     * @return array{slot: string, time: string, label: string}
     */
    public function inferScheduleFromRepatTime(?string $repat): array
    {
        $rep = trim((string) $repat);
        $lower = mb_strtolower($rep);

        if (
            str_contains($lower, 'صباح') || str_contains($lower, 'فطور')
            || str_contains($lower, 'morning') || str_contains($lower, 'breakfast')
        ) {
            return ['slot' => 'morning', 'time' => '08:00:00', 'label' => '08:00 صباحاً'];
        }
        if (
            str_contains($lower, 'ظهر') || str_contains($lower, 'غداء')
            || str_contains($lower, 'noon') || str_contains($lower, 'afternoon')
        ) {
            return ['slot' => 'afternoon', 'time' => '13:30:00', 'label' => '13:30 ظهراً'];
        }
        if (
            str_contains($lower, 'مساء') || str_contains($lower, 'عشاء')
            || str_contains($lower, 'ليل') || str_contains($lower, 'evening')
            || str_contains($lower, 'night')
        ) {
            return ['slot' => 'evening', 'time' => '20:30:00', 'label' => '20:30 مساءً'];
        }

        if (preg_match('/(\d{1,2}):(\d{2})/', $rep, $m)) {
            $h = (int) $m[1];
            $min = (int) $m[2];
            if ($h >= 0 && $h <= 23 && $min >= 0 && $min <= 59) {
                return [
                    'slot' => 'default',
                    'time' => sprintf('%02d:%02d:00', $h, $min),
                    'label' => sprintf('%02d:%02d', $h, $min),
                ];
            }
        }

        return ['slot' => 'default', 'time' => '08:00:00', 'label' => '08:00 صباحاً'];
    }

    public function occurrenceKey(string $civilDate, string $slot): string
    {
        return $civilDate.':'.$slot;
    }

    public function scheduledCarbon(string $civilDate, string $time): Carbon
    {
        return Carbon::parse($civilDate.' '.$time);
    }

    public function graceEndsAt(Carbon $scheduledAt): Carbon
    {
        return $scheduledAt->copy()->addMinutes(self::GRACE_MINUTES);
    }

    /**
     * Compute display state for an occurrence at $now.
     */
    public function displayState(MedicationDoseOccurrence $occ, ?Carbon $now = null): string
    {
        $now = $now ?? Carbon::now();
        $persisted = $occ->adherence_state;

        if ($persisted === self::STATE_TAKEN) {
            return self::DISPLAY_TAKEN;
        }
        if ($persisted === self::STATE_LATE_CONFIRMED) {
            return self::DISPLAY_LATE_CONFIRMED;
        }

        $scheduled = $this->scheduledCarbon(
            $occ->scheduled_date->format('Y-m-d'),
            $this->normalizeTime((string) $occ->scheduled_time)
        );
        $graceEnd = $this->graceEndsAt($scheduled);

        if ($now->lt($scheduled)) {
            return self::DISPLAY_UPCOMING;
        }
        if ($now->lte($graceEnd)) {
            return self::DISPLAY_DUE;
        }

        return self::DISPLAY_OVERDUE_NOT_CONFIRMED;
    }

    public function arabicDisplayLabel(string $displayState): string
    {
        return match ($displayState) {
            self::DISPLAY_UPCOMING => 'قادم',
            self::DISPLAY_DUE => 'مستحق',
            self::DISPLAY_OVERDUE_NOT_CONFIRMED => 'متأخر — غير مؤكد',
            self::DISPLAY_TAKEN => 'تم التناول',
            self::DISPLAY_LATE_CONFIRMED => 'تأكيد متأخر',
            default => 'غير مؤكد',
        };
    }

    /**
     * Materialize occurrences for elderly meds on civil dates within horizon.
     * Does not rewrite confirmed rows when schedule text changes.
     *
     * @param  list<string>  $civilDates  Y-m-d
     * @return list<MedicationDoseOccurrence>
     */
    public function ensureOccurrencesForDates(int $elderlyId, array $civilDates, ?Carbon $now = null): array
    {
        $now = $now ?? Carbon::now();
        $dates = array_values(array_unique(array_filter($civilDates)));
        if ($dates === []) {
            return [];
        }

        $meds = Medication::query()
            ->where('Elderly_ID', $elderlyId)
            ->orderBy('Medicayion_ID')
            ->get();

        $out = [];
        foreach ($meds as $med) {
            foreach ($dates as $date) {
                $out[] = $this->ensureOccurrenceForMedicationDay($med, $date, $now);
            }
        }

        return $out;
    }

    public function ensureOccurrenceForMedicationDay(
        Medication $med,
        string $civilDate,
        ?Carbon $now = null
    ): MedicationDoseOccurrence {
        $inferred = $this->inferScheduleFromRepatTime($med->M_RepatTime);
        $key = $this->occurrenceKey($civilDate, $inferred['slot']);

        $existing = MedicationDoseOccurrence::query()
            ->where('Medicayion_ID', $med->Medicayion_ID)
            ->where('occurrence_key', $key)
            ->first();

        if ($existing) {
            // Freeze schedule on existing rows so edits do not rewrite past adherence.
            return $existing;
        }

        // If this civil day already has an occurrence (any slot), keep it.
        // Schedule edits must not invent a second dose or rewrite history.
        $sameDay = MedicationDoseOccurrence::query()
            ->where('Medicayion_ID', $med->Medicayion_ID)
            ->whereDate('scheduled_date', $civilDate)
            ->orderBy('DoseOccurrence_ID')
            ->first();
        if ($sameDay) {
            return $sameDay;
        }

        $occ = MedicationDoseOccurrence::create([
            'occurrence_key' => $key,
            'Medicayion_ID' => $med->Medicayion_ID,
            'Elderly_ID' => $med->Elderly_ID,
            'scheduled_date' => $civilDate,
            'scheduled_time' => $inferred['time'],
            'slot' => $inferred['slot'],
            'schedule_text_snapshot' => $med->M_RepatTime,
            'adherence_state' => self::STATE_UNCONFIRMED,
        ]);

        MedicationDoseEvent::create([
            'DoseOccurrence_ID' => $occ->DoseOccurrence_ID,
            'Medicayion_ID' => $occ->Medicayion_ID,
            'Elderly_ID' => $occ->Elderly_ID,
            'event_type' => 'materialized',
            'actor_type' => 'system',
            'actor_id' => null,
            'event_at' => $now ?? Carbon::now(),
            'meta_json' => json_encode([
                'slot' => $inferred['slot'],
                'scheduled_time' => $inferred['time'],
            ], JSON_UNESCAPED_UNICODE),
        ]);

        return $occ;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function serializeOccurrences(
        iterable $occurrences,
        ?Carbon $now = null,
        bool $includeMed = true
    ): array {
        $now = $now ?? Carbon::now();
        $rows = [];
        foreach ($occurrences as $occ) {
            $display = $this->displayState($occ, $now);
            $scheduled = $this->scheduledCarbon(
                $occ->scheduled_date->format('Y-m-d'),
                $this->normalizeTime((string) $occ->scheduled_time)
            );
            $med = $includeMed ? $occ->medication : null;
            $rows[] = [
                'DoseOccurrence_ID' => $occ->DoseOccurrence_ID,
                'occurrence_key' => $occ->occurrence_key,
                'Medicayion_ID' => $occ->Medicayion_ID,
                'Elderly_ID' => $occ->Elderly_ID,
                'scheduled_date' => $occ->scheduled_date->format('Y-m-d'),
                'scheduled_time' => $this->normalizeTime((string) $occ->scheduled_time),
                'scheduled_at' => $scheduled->format('Y-m-d H:i:s'),
                'grace_ends_at' => $this->graceEndsAt($scheduled)->format('Y-m-d H:i:s'),
                'grace_minutes' => self::GRACE_MINUTES,
                'slot' => $occ->slot,
                'schedule_text_snapshot' => $occ->schedule_text_snapshot,
                'adherence_state' => $occ->adherence_state,
                'display_state' => $display,
                'display_label_ar' => $this->arabicDisplayLabel($display),
                'confirmed_at' => $occ->confirmed_at
                    ? $occ->confirmed_at->format('Y-m-d H:i:s')
                    : null,
                'confirmed_by_type' => $occ->confirmed_by_type,
                'confirmed_by_id' => $occ->confirmed_by_id,
                'is_late_confirmed' => $display === self::DISPLAY_LATE_CONFIRMED,
                'can_confirm' => in_array($display, [
                    self::DISPLAY_UPCOMING,
                    self::DISPLAY_DUE,
                    self::DISPLAY_OVERDUE_NOT_CONFIRMED,
                ], true),
                'medication' => $med ? [
                    'Medicayion_ID' => $med->Medicayion_ID,
                    'M_Name' => $med->M_Name,
                    'M_much' => $med->M_much,
                    'M_RepatTime' => $med->M_RepatTime,
                    'Elderly_ID' => $med->Elderly_ID,
                ] : null,
                // P2.3 notification timing contract (no scheduler in P2.2)
                'notification_contract' => [
                    'deferred_to' => 'P2.3',
                    'candidate_trigger' => 'grace_elapsed_unconfirmed',
                    'notify_role' => 'linked_caregiver',
                    'payload_keys' => [
                        'Elderly_ID',
                        'Medicayion_ID',
                        'occurrence_key',
                        'scheduled_at',
                        'grace_ends_at',
                    ],
                ],
            ];
        }

        return $rows;
    }

    /**
     * Confirm a dose. Elderly only (caller AuthZ). Idempotent on retries.
     *
     * @return array{ok: bool, code?: string, message?: string, occurrence?: MedicationDoseOccurrence, created?: bool}
     */
    public function confirmDose(
        Medication $med,
        Elderly|Caregiver $actor,
        string $civilDate,
        ?string $occurrenceKey = null,
        ?string $clientConfirmId = null,
        ?Carbon $now = null
    ): array {
        $now = $now ?? Carbon::now();

        if ($clientConfirmId) {
            $byClient = MedicationDoseOccurrence::query()
                ->where('client_confirm_id', $clientConfirmId)
                ->first();
            if ($byClient) {
                if ((int) $byClient->Medicayion_ID !== (int) $med->Medicayion_ID) {
                    return [
                        'ok' => false,
                        'code' => 'idempotency_conflict',
                        'message' => 'مفتاح التأكيد مستخدم لجرعة أخرى',
                    ];
                }

                return [
                    'ok' => true,
                    'occurrence' => $byClient->fresh(['medication']),
                    'created' => false,
                    'idempotent' => true,
                ];
            }
        }

        $occ = null;
        if ($occurrenceKey) {
            $occ = MedicationDoseOccurrence::query()
                ->where('Medicayion_ID', $med->Medicayion_ID)
                ->where('occurrence_key', $occurrenceKey)
                ->first();
        }
        if (! $occ) {
            $occ = $this->ensureOccurrenceForMedicationDay($med, $civilDate, $now);
            if ($occurrenceKey && $occ->occurrence_key !== $occurrenceKey) {
                // Explicit key for a different slot — find/create that key only if slot matches med schedule.
                $existingKeyed = MedicationDoseOccurrence::query()
                    ->where('Medicayion_ID', $med->Medicayion_ID)
                    ->where('occurrence_key', $occurrenceKey)
                    ->first();
                if ($existingKeyed) {
                    $occ = $existingKeyed;
                }
            }
        }

        if ((int) $occ->Elderly_ID !== (int) $med->Elderly_ID) {
            return [
                'ok' => false,
                'code' => 'ownership_mismatch',
                'message' => 'عدم تطابق ملكية الجرعة',
            ];
        }

        if (in_array($occ->adherence_state, [self::STATE_TAKEN, self::STATE_LATE_CONFIRMED], true)) {
            return [
                'ok' => true,
                'occurrence' => $occ->fresh(['medication']),
                'created' => false,
                'idempotent' => true,
            ];
        }

        $scheduled = $this->scheduledCarbon(
            $occ->scheduled_date->format('Y-m-d'),
            $this->normalizeTime((string) $occ->scheduled_time)
        );
        $late = $now->gt($this->graceEndsAt($scheduled));
        $newState = $late ? self::STATE_LATE_CONFIRMED : self::STATE_TAKEN;

        $actorType = $actor instanceof Elderly ? 'elderly' : 'caregiver';
        $actorId = $actor instanceof Elderly
            ? (int) $actor->Eldery_ID
            : (int) $actor->Caregivers_ID;

        try {
            DB::transaction(function () use (
                $occ,
                $newState,
                $now,
                $actorType,
                $actorId,
                $clientConfirmId,
                $late
            ) {
                $locked = MedicationDoseOccurrence::query()
                    ->where('DoseOccurrence_ID', $occ->DoseOccurrence_ID)
                    ->lockForUpdate()
                    ->first();

                if (! $locked) {
                    throw new \RuntimeException('occurrence_missing');
                }

                if (in_array($locked->adherence_state, [self::STATE_TAKEN, self::STATE_LATE_CONFIRMED], true)) {
                    return;
                }

                $locked->adherence_state = $newState;
                $locked->confirmed_at = $now;
                $locked->confirmed_by_type = $actorType;
                $locked->confirmed_by_id = $actorId;
                if ($clientConfirmId && empty($locked->client_confirm_id)) {
                    $locked->client_confirm_id = $clientConfirmId;
                }
                $locked->save();

                MedicationDoseEvent::create([
                    'DoseOccurrence_ID' => $locked->DoseOccurrence_ID,
                    'Medicayion_ID' => $locked->Medicayion_ID,
                    'Elderly_ID' => $locked->Elderly_ID,
                    'event_type' => $late ? 'late_confirmed' : 'confirmed',
                    'actor_type' => $actorType,
                    'actor_id' => $actorId,
                    'event_at' => $now,
                    'meta_json' => json_encode([
                        'adherence_state' => $newState,
                        'grace_minutes' => self::GRACE_MINUTES,
                    ], JSON_UNESCAPED_UNICODE),
                ]);
            });
        } catch (\Illuminate\Database\QueryException $e) {
            // Unique client_confirm_id race → reload idempotent success.
            if ($clientConfirmId) {
                $again = MedicationDoseOccurrence::query()
                    ->where('client_confirm_id', $clientConfirmId)
                    ->first();
                if ($again) {
                    return [
                        'ok' => true,
                        'occurrence' => $again->fresh(['medication']),
                        'created' => false,
                        'idempotent' => true,
                    ];
                }
            }

            return [
                'ok' => false,
                'code' => 'confirm_failed',
                'message' => 'تعذّر حفظ تأكيد الجرعة',
            ];
        }

        return [
            'ok' => true,
            'occurrence' => $occ->fresh(['medication']),
            'created' => true,
            'idempotent' => false,
        ];
    }

    /**
     * Clamp history range to MAX_HISTORY_DAYS inclusive.
     *
     * @return array{0: string, 1: string}|null  [from, to] Y-m-d or null if invalid
     */
    public function clampHistoryRange(?string $from, ?string $to, ?Carbon $now = null): ?array
    {
        $now = $now ?? Carbon::now();
        $toDate = $to ? Carbon::parse($to)->startOfDay() : $now->copy()->startOfDay();
        $fromDate = $from
            ? Carbon::parse($from)->startOfDay()
            : $toDate->copy()->subDays(self::MAX_HISTORY_DAYS - 1);

        if ($fromDate->gt($toDate)) {
            return null;
        }

        $span = $fromDate->diffInDays($toDate) + 1;
        if ($span > self::MAX_HISTORY_DAYS) {
            $fromDate = $toDate->copy()->subDays(self::MAX_HISTORY_DAYS - 1);
        }

        return [$fromDate->format('Y-m-d'), $toDate->format('Y-m-d')];
    }

    /**
     * @return list<string>
     */
    public function dateSpan(string $from, string $to): array
    {
        $dates = [];
        $cursor = Carbon::parse($from)->startOfDay();
        $end = Carbon::parse($to)->startOfDay();
        while ($cursor->lte($end)) {
            $dates[] = $cursor->format('Y-m-d');
            $cursor->addDay();
        }

        return $dates;
    }

    private function normalizeTime(string $time): string
    {
        if (preg_match('/^\d{2}:\d{2}:\d{2}$/', $time)) {
            return $time;
        }
        if (preg_match('/^\d{2}:\d{2}$/', $time)) {
            return $time.':00';
        }
        try {
            return Carbon::parse($time)->format('H:i:s');
        } catch (\Throwable) {
            return '08:00:00';
        }
    }
}
