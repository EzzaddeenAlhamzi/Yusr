<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use App\Models\Traits\HasCustomIncrementingId;

class Elderly extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, HasCustomIncrementingId;

    protected $table = 'elderly';
    protected $primaryKey = 'Eldery_ID';
    public $timestamps = false;

    protected $fillable = [
        'E_Name',
        'E_sex',
        'E_PhonNumber',
        'E_Email',
        'E_Password',
        'location_sharing_enabled',
    ];

    protected $casts = [
        'location_sharing_enabled' => 'boolean',
    ];

    protected $hidden = [
        'E_Password',
    ];

    public function caregivers()
    {
        return $this->hasMany(Caregiver::class, 'Eldery_ID', 'Eldery_ID');
    }

    public function medications()
    {
        return $this->hasMany(Medication::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function appointments()
    {
        return $this->hasMany(Appointment::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function healthRecords()
    {
        return $this->hasMany(HealthMonitoring::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function emergencyLogs()
    {
        return $this->hasMany(EmergencyLog::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function emergencyContacts()
    {
        return $this->hasMany(EmergencyContact::class, 'Eldery_ID', 'Eldery_ID');
    }

    public function devices()
    {
        return $this->hasMany(Device::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function locations()
    {
        return $this->hasMany(LocationTracking::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function safeZones()
    {
        return $this->hasMany(SafeZone::class, 'Zldery_ID', 'Eldery_ID');
    }

    public function typesOfCare()
    {
        return $this->hasMany(TypeOfCare::class, 'Eldery_ID', 'Eldery_ID');
    }
}
