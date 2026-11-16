<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class Notification extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'notifications';
    protected $primaryKey = 'Notifications_ID';
    public $timestamps = false;

    protected $fillable = [
        'N_Title',
        'N_Message',
        'N_Type',
        'N_Date',
        'N_Time',
        'N_Status',
        'Caregiver_ID',
        'Eldery_ID',
    ];

    public function caregiver()
    {
        return $this->belongsTo(Caregiver::class, 'Caregiver_ID', 'Caregivers_ID');
    }

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Eldery_ID', 'Eldery_ID');
    }
}
