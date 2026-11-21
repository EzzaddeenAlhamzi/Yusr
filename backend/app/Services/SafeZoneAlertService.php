<?php

namespace App\Services;

use App\Models\Caregiver;
use App\Models\Notification;
use App\Models\SafeZone;
use App\Models\ZonePresenceState;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * P2.4-B — evaluate active approved zones on a new GPS fix; emit in-app CG alerts.
 * Uses P2.3 notifications columns (event_type + occurrence_key). No FCM. No auto SOS.
 */
class SafeZoneAlertService
{
    public const EVENT_EXIT = 'safe_zone_exit';

    public const EVENT_ENTER = 'safe_zone_enter';

    public const N_TYPE_EXIT = 'safe_zone_exit';

    public const N_TYPE_ENTER = 'safe_zone_enter';

    public function __construct(
        private readonly GeofenceEngine $engine
    ) {
    }

    public function isReady(): bool
    {
        return Schema::hasTable('safe_zones')
            && Schema::hasTable('zone_presence_states')
            && Schema::hasTable('notifications')
            && Schema::hasColumn('notifications', 'event_type')
            && Schema::hasColumn('notifications', 'occurrence_key')
            && Schema::hasColumn('safe_zones', 'center_lat');
    }

    /**
     * @return array{evaluated:int,events:int,alerts:int}
     */
    public function evaluateFix(
        int $elderlyId,
        float $lat,
        float $lng,
        ?float $accuracyMeters,
        ?Carbon $now = null
    ): array {
        $now = $now ? $now->copy() : Carbon::now();
        $evaluated = 0;
        $events = 0;
        $alerts = 0;

        if (! $this->isReady()) {
            return ['evaluated' => 0, 'events' => 0, 'alerts' => 0];
        }

        $zones = SafeZone::query()
            ->where('Zldery_ID', $elderlyId)
            ->where('approval_status', 'approved')
            ->where(function ($q) {
                $q->where('Z_state', 'active')
                    ->orWhere('Z_state', 'Active')
                    ->orWhere('Z_state', 'نشط');
            })
            ->whereNotNull('center_lat')
            ->whereNotNull('center_lng')
            ->whereNotNull('radius_meters')
            ->get();

        foreach ($zones as $zone) {
            $evaluated++;
            $classified = $this->engine->classify(
                $lat,
                $lng,
                $accuracyMeters,
                (float) $zone->center_lat,
                (float) $zone->center_lng,
                (float) $zone->radius_meters
            );

            $presence = ZonePresenceState::query()
                ->where('Elderly_ID', $elderlyId)
                ->where('Zone_ID', (int) $zone->Zone_ID)
                ->first();

            $prev = $presence?->state;
            $transition = $this->engine->transition($prev, $classified['state']);

            if (! $presence) {
                $presence = new ZonePresenceState([
                    'Elderly_ID' => $elderlyId,
                    'Zone_ID' => (int) $zone->Zone_ID,
                ]);
            }

            $presence->state = $transition['new_state'];
            $presence->updated_at = $now->toDateTimeString();

            if ($transition['event'] !== null) {
                $events++;
                $presence->last_event = $transition['event'];
                $presence->last_transition_at = $now->toDateTimeString();
                $alerts += $this->notifyCaregivers(
                    $elderlyId,
                    $zone,
                    $transition['event'],
                    $now
                );
            }

            $presence->save();
        }

        return [
            'evaluated' => $evaluated,
            'events' => $events,
            'alerts' => $alerts,
        ];
    }

    private function notifyCaregivers(
        int $elderlyId,
        SafeZone $zone,
        string $event,
        Carbon $now
    ): int {
        $caregivers = Caregiver::query()->where('Eldery_ID', $elderlyId)->get();
        if ($caregivers->isEmpty()) {
            return 0;
        }

        $eventType = $event === GeofenceEngine::EVENT_EXIT
            ? self::EVENT_EXIT
            : self::EVENT_ENTER;
        $nType = $event === GeofenceEngine::EVENT_EXIT
            ? self::N_TYPE_EXIT
            : self::N_TYPE_ENTER;

        // Debounce key: zone + event + minute bucket (no duplicate exit spam same minute).
        $bucket = $now->format('YmdHi');
        $occurrenceKey = 'zone:'.$zone->Zone_ID.':'.$event.':'.$bucket;

        $zoneName = (string) ($zone->Z_Name ?: 'منطقة آمنة');
        $title = $event === GeofenceEngine::EVENT_EXIT
            ? 'خروج من المنطقة الآمنة'
            : 'دخول إلى المنطقة الآمنة';
        $message = $event === GeofenceEngine::EVENT_EXIT
            ? 'غادر كبير السن منطقة «'.$zoneName.'» (تنبيه داخل التطبيق — ليست طوارئ تلقائية).'
            : 'دخل كبير السن منطقة «'.$zoneName.'».';

        $created = 0;
        foreach ($caregivers as $cg) {
            $cgId = (int) $cg->Caregivers_ID;
            if (Notification::query()
                ->where('Caregiver_ID', $cgId)
                ->where('event_type', $eventType)
                ->where('occurrence_key', $occurrenceKey)
                ->exists()) {
                continue;
            }

            try {
                DB::transaction(function () use (
                    $cgId,
                    $elderlyId,
                    $eventType,
                    $nType,
                    $occurrenceKey,
                    $title,
                    $message,
                    $now
                ) {
                    if (Notification::query()
                        ->where('Caregiver_ID', $cgId)
                        ->where('event_type', $eventType)
                        ->where('occurrence_key', $occurrenceKey)
                        ->lockForUpdate()
                        ->exists()) {
                        return;
                    }

                    Notification::create([
                        'N_Title' => $title,
                        'N_Message' => $message,
                        'N_Type' => $nType,
                        'event_type' => $eventType,
                        'occurrence_key' => $occurrenceKey,
                        'N_Date' => $now->format('Y-m-d'),
                        'N_Time' => $now->format('H:i:s'),
                        'N_Status' => 'غير مقروء',
                        'Caregiver_ID' => $cgId,
                        'Eldery_ID' => $elderlyId,
                    ]);
                });
                $created++;
            } catch (\Throwable $e) {
                // Unique race — treat as skip.
            }
        }

        return $created;
    }
}
