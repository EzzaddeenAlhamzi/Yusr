<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class ServiceRequest extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'services_request';
    protected $primaryKey = 'Service_Requst_ID';
    public $timestamps = false;

    protected $fillable = [
        'Requst_Date',
        'Requst_Status',
        'Requst_Note',
        'Service_ID',
        'Caregivers_id',
        'Elderly_ID',
    ];

    public function service()
    {
        return $this->belongsTo(Service::class, 'Service_ID', 'Service_ID');
    }

    public function caregiver()
    {
        return $this->belongsTo(Caregiver::class, 'Caregivers_id', 'Caregivers_ID');
    }

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Elderly_ID', 'Eldery_ID');
    }
}
