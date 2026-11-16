<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class Device extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'devices';
    protected $primaryKey = 'Devices_ID';
    public $timestamps = false;

    protected $fillable = [
        'D_Type',
        'T_Number',
        'Elderly_ID',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function healthRecords()
    {
        return $this->hasMany(HealthMonitoring::class, 'Devices_ID', 'Devices_ID');
    }
}
