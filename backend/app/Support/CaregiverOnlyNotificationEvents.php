<?php

namespace App\Support;

use App\Services\CaregiverOverdueAlertService;
use App\Services\SafeZoneAlertService;

/**
 * Server-owned caregiver-only notification event_type values.
 * Elderly list/markRead must not expose these (P2.3 M-1 + P2.4 M-P24-1).
 */
class CaregiverOnlyNotificationEvents
{
    /**
     * @return list<string>
     */
    public static function types(): array
    {
        return [
            CaregiverOverdueAlertService::EVENT_TYPE,
            SafeZoneAlertService::EVENT_EXIT,
            SafeZoneAlertService::EVENT_ENTER,
        ];
    }

    public static function isCaregiverOnly(?string $eventType): bool
    {
        if ($eventType === null || $eventType === '') {
            return false;
        }

        return in_array($eventType, self::types(), true);
    }
}
