<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class MedicationDoseEvent extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'medication_dose_events';
    protected $primaryKey = 'DoseEvent_ID';

    protected $fillable = [
        'DoseOccurrence_ID',
        'Medicayion_ID',
        'Elderly_ID',
        'event_type',
        'actor_type',
        'actor_id',
        'event_at',
        'meta_json',
    ];

    protected $casts = [
        'event_at' => 'datetime',
    ];

    public function occurrence()
    {
        return $this->belongsTo(
            MedicationDoseOccurrence::class,
            'DoseOccurrence_ID',
            'DoseOccurrence_ID'
        );
    }
}
