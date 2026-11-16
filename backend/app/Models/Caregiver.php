<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use App\Models\Traits\HasCustomIncrementingId;

class Caregiver extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, HasCustomIncrementingId;

    protected $table = 'caregivers';
    protected $primaryKey = 'Caregivers_ID';
    public $timestamps = false;

    protected $fillable = [
        'C_Name',
        'C_PhonNumber',
        'C_Relationship',
        'C_Email',
        'C_Password',
        'Eldery_ID',
    ];

    protected $hidden = [
        'C_Password',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Eldery_ID', 'Eldery_ID');
    }

    public function serviceRequests()
    {
        return $this->hasMany(ServiceRequest::class, 'Caregivers_id', 'Caregivers_ID');
    }

    public function typesOfCare()
    {
        return $this->hasMany(TypeOfCare::class, 'Caregivers_ID', 'Caregivers_ID');
    }
}
