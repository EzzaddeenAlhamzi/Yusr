<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class Admin extends Authenticatable
{
    use HasApiTokens, HasFactory;

    protected $table = 'admin';
    protected $primaryKey = 'Admin_ID';
    public $timestamps = false;

    protected $fillable = [
        'A_Name',
        'A_Email',
        'A_Number',
        'A_password',
    ];

    protected $hidden = [
        'A_password',
    ];
}
