<?php

namespace App\Policies;

use App\Models\Caregiver;
use App\Models\Elderly;
use App\Support\YusrAccess;

class CaregiverPolicy
{
    public function view(Caregiver|Elderly $actor, Caregiver $caregiver): bool
    {
        return YusrAccess::canViewCaregiver($actor, $caregiver->Caregivers_ID);
    }

    public function update(Caregiver|Elderly $actor, Caregiver $caregiver): bool
    {
        return YusrAccess::canModifyCaregiver($actor, $caregiver->Caregivers_ID);
    }
}
