<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class MedicationDoseOccurrence extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'medication_dose_occurrences';
    protected $primaryKey = 'DoseOccurrence_ID';

    protected $fillable = [
        'occurrence_key',
        'Medicayion_ID',
        'Elderly_ID',
        'scheduled_date',
        'scheduled_time',
        'slot',
        'schedule_text_snapshot',
        'adherence_state',
        'confirmed_at',
        'confirmed_by_type',
        'confirmed_by_id',
        'client_confirm_id',
    ];

    protected $casts = [
        'confirmed_at' => 'datetime',
        'scheduled_date' => 'date',
    ];

    public function medication()
    {
        return $this->belongsTo(Medication::class, 'Medicayion_ID', 'Medicayion_ID');
    }

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function events()
    {
        return $this->hasMany(MedicationDoseEvent::class, 'DoseOccurrence_ID', 'DoseOccurrence_ID');
    }
}
