<?php

namespace App\Policies;

use App\Models\Appointment;
use App\Models\Caregiver;
use App\Models\Elderly;
use App\Support\YusrAccess;

/**
 * Appointment ownership: actor may act only on appointments whose Elderly_ID
 * is in the actor's accessible set (self for elderly; linked Eldery_ID for CG).
 */
class AppointmentPolicy
{
    public function view(Caregiver|Elderly $actor, Appointment $appointment): bool
    {
        return YusrAccess::canAccessElderly($actor, $appointment->Elderly_ID);
    }

    public function update(Caregiver|Elderly $actor, Appointment $appointment): bool
    {
        return YusrAccess::canAccessElderly($actor, $appointment->Elderly_ID);
    }

    public function delete(Caregiver|Elderly $actor, Appointment $appointment): bool
    {
        return YusrAccess::canAccessElderly($actor, $appointment->Elderly_ID);
    }
}
