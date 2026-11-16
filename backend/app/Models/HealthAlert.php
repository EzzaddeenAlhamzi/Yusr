<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class HealthAlert extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'health_alerts';
    protected $primaryKey = 'Alert_ID';
    public $timestamps = false;

    protected $fillable = [
        'A_Type',
        'A_Description',
        'A_Level',
        'A_Date',
        'A_Status',
        'H_Record_ID',
    ];

    public function healthRecord()
    {
        return $this->belongsTo(HealthMonitoring::class, 'H_Record_ID', 'H_Record_ID');
    }
}
