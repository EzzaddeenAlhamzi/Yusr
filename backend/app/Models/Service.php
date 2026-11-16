<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class Service extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'services';
    protected $primaryKey = 'Service_ID';
    public $timestamps = false;

    protected $fillable = [
        'S_Name',
        'S_Type',
        'S_Description',
        'S_Status',
        'Admin_ID',
    ];

    public function requests()
    {
        return $this->hasMany(ServiceRequest::class, 'Service_ID', 'Service_ID');
    }
}
