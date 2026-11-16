<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class SafeZone extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'safe_zones';
    protected $primaryKey = 'Zone_ID';
    public $timestamps = false;

    protected $fillable = [
        'Z_Name',
        'Z_state',
        'Z_Limit',
        'Alert_ID',
        'Location_ID',
        'Zldery_ID',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Zldery_ID', 'Eldery_ID');
    }
}
