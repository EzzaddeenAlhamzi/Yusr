<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class HealthMonitoring extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'health_monitoring';
    protected $primaryKey = 'H_Record_ID';
    public $timestamps = false;

    protected $fillable = [
        'Heart_Rate',
        'Blood_pressure',
        'Oxyger',
        'Temperature',
        'steps',
        'H_Type',
        'H_Date',
        'H_Result',
        'Elderly_ID',
        'Devices_ID',
        'Emergency_ID',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function device()
    {
        return $this->belongsTo(Device::class, 'Devices_ID', 'Devices_ID');
    }

    public function emergency()
    {
        return $this->belongsTo(EmergencyLog::class, 'Emergency_ID', 'Emergency_ID');
    }

    public function healthAlerts()
    {
        return $this->hasMany(HealthAlert::class, 'H_Record_ID', 'H_Record_ID');
    }
}
