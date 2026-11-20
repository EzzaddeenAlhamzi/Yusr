<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Traits\HasCustomIncrementingId;

class Notification extends Model
{
    use HasFactory, HasCustomIncrementingId;

    protected $table = 'notifications';
    protected $primaryKey = 'Notifications_ID';
    public $timestamps = false;

    public const STATUS_UNREAD = 'غير مقروء';
    public const STATUS_READ = 'مقروء';

    protected $fillable = [
        'N_Title',
        'N_Message',
        'N_Type',
        'event_type',
        'occurrence_key',
        'DoseOccurrence_ID',
        'N_Date',
        'N_Time',
        'N_Status',
        'Caregiver_ID',
        'Eldery_ID',
    ];

    public function caregiver()
    {
        return $this->belongsTo(Caregiver::class, 'Caregiver_ID', 'Caregivers_ID');
    }

    public function elderly()
    {
        return $this->belongsTo(Elderly::class, 'Eldery_ID', 'Eldery_ID');
    }

    public function isUnread(): bool
    {
        $s = trim((string) $this->N_Status);

        return $s === self::STATUS_UNREAD
            || $s === 'unread'
            || $s === 'جديد'
            || $s === ''
            || strcasecmp($s, 'Active') === 0;
    }

    public function markRead(): void
    {
        $this->N_Status = self::STATUS_READ;
        $this->save();
    }
}
