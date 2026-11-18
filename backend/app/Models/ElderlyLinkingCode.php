<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ElderlyLinkingCode extends Model
{
    public $timestamps = false;

    protected $table = 'elderly_linking_codes';

    protected $fillable = [
        'Eldery_ID',
        'code_hash',
        'expires_at',
        'consumed_at',
        'created_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
        'created_at' => 'datetime',
    ];

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Eldery_ID', 'Eldery_ID');
    }

    public function isActive(): bool
    {
        return $this->consumed_at === null
            && $this->expires_at !== null
            && $this->expires_at->isFuture();
    }
}
