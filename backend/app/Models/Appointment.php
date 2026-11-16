<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class Appointment extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'appointments';
    protected $primaryKey = 'Appointment_ID';
    public $timestamps = false;

    protected $fillable = [
        'A_Time',
        'A_Date',
        'A_DateType',
        'A_Location',
        'A_Note',
        'Elderly_ID',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function reminders()
    {
        return $this->hasMany(Reminder::class, 'Appointment_ID', 'Appointment_ID');
    }
}
