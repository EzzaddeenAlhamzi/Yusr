<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class Medication extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'medications';
    protected $primaryKey = 'Medicayion_ID';
    public $timestamps = false;

    protected $fillable = [
        'M_Name',
        'M_much',
        'M_RepatTime',
        'Elderly_ID',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Elderly_ID', 'Eldery_ID');
    }

    public function doseOccurrences()
    {
        return $this->hasMany(
            MedicationDoseOccurrence::class,
            'Medicayion_ID',
            'Medicayion_ID'
        );
    }
}
