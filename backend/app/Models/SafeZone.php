<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class SafeZone extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'safe_zones';
    protected $primaryKey = 'Zone_ID';
    public $timestamps = false;

    protected $fillable = [
        'Z_Name',
        'Z_state',
        'Z_Limit',
        'center_lat',
        'center_lng',
        'radius_meters',
        'approval_status',
        'created_by_role',
        'created_by_caregiver_id',
        'activated_at',
        'created_at',
        'updated_at',
        'Alert_ID',
        'Location_ID',
        'Zldery_ID',
        'replaces_zone_id',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Zldery_ID', 'Eldery_ID');
    }
}
