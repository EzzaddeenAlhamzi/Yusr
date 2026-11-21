<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class ZonePresenceState extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'zone_presence_states';

    protected $primaryKey = 'Presence_ID';

    public $timestamps = false;

    protected $fillable = [
        'Elderly_ID',
        'Zone_ID',
        'state',
        'last_event',
        'last_transition_at',
        'updated_at',
    ];
}
