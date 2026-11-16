<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class LocationTracking extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'location_tracking';
    protected $primaryKey = 'Location_ID';
    public $timestamps = false;

    protected $fillable = [
        'L_Latitude',
        'L_Longitude',
        'L_UpdateTime',
        'L_Scor',
        'Elderly_ID',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Elderly_ID', 'Eldery_ID');
    }
}
