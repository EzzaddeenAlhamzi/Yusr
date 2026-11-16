<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class TypeOfCare extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'type_of_care';
    protected $primaryKey = 'Tc_id';
    public $timestamps = false;

    protected $fillable = [
        'Care_Type',
        'Caregivers_ID',
        'Eldery_ID',
    ];

    public function caregiver()
    {
        return $this->belongsTo(Caregiver::class, 'Caregivers_ID', 'Caregivers_ID');
    }

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Eldery_ID', 'Eldery_ID');
    }
}
