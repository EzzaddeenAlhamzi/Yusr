<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class EmergencyContact extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'emergency_contacts';
    protected $primaryKey = 'contact_ID';
    public $timestamps = false;

    protected $fillable = [
        'contact_Name',
        'Phone_Number',
        'Relationship',
        'Priority',
        'Eldery_ID',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Eldery_ID', 'Eldery_ID');
    }
}
