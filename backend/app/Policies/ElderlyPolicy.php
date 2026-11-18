<?php

namespace App\Policies;

use App\Models\Caregiver;
use App\Models\Elderly;
use App\Support\YusrAccess;

class ElderlyPolicy
{
    public function view(Caregiver|Elderly $actor, Elderly $elderly): bool
    {
        return YusrAccess::canAccessElderly($actor, $elderly->Eldery_ID);
    }

    public function update(Caregiver|Elderly $actor, Elderly $elderly): bool
    {
        return YusrAccess::canModifyElderly($actor, $elderly->Eldery_ID);
    }

    /**
     * Linking: only the authenticated caregiver may attach themselves after a
     * valid single-use linking code was consumed (controller enforces code path).
     */
    public function link(Caregiver|Elderly $actor, Elderly $elderly): bool
    {
        return $actor instanceof Caregiver
            && Elderly::query()->where('Eldery_ID', $elderly->Eldery_ID)->exists();
    }
}
