<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LinkingCodeAttempt extends Model
{
    public $timestamps = false;

    protected $table = 'linking_code_attempts';

    protected $fillable = [
        'Caregivers_ID',
        'ip_address',
        'attempted_at',
    ];

    protected $casts = [
        'attempted_at' => 'datetime',
    ];
}
