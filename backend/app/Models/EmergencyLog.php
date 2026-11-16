<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class EmergencyLog extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'emergency_log';
    protected $primaryKey = 'Emergency_ID';
    public $timestamps = false;

    protected $fillable = [
        'E_Time',
        'E_Date',
        'E_Location',
        'latitude',
        'Longitude',
        'E_State',
        'Descripion',
        'Elderly_ID',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function healthRecords()
    {
        return $this->hasMany(HealthMonitoring::class, 'Emergency_ID', 'Emergency_ID');
    }
}
