<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $caregiverId = $request->query('caregiver_id', $request->query('Caregiver_ID', $request->input('caregiver_id', $request->input('Caregiver_ID'))));
        $elderlyId = $request->query('elderly_id', $request->query('Eldery_ID', $request->input('elderly_id', $request->input('Eldery_ID'))));

        $query = Notification::query();

        if ($caregiverId) {
            $query->where('Caregiver_ID', $caregiverId);
        }
        if ($elderlyId) {
            $query->orWhere('Eldery_ID', $elderlyId);
        }

        $notifications = $query->orderBy('Notifications_ID', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $notifications
        ]);
    }

    public function store(Request $request)
    {
        $title = trim($request->input('N_Title', ''));
        $message = trim($request->input('N_Message', ''));
        $type = $request->input('N_Type', 'ط¹ط§ظ…');
        $caregiverId = $request->input('Caregiver_ID');
        $elderlyId = $request->input('Eldery_ID', $request->input('Elderly_ID'));

        if (empty($title) || empty($message)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط¹ظ†ظˆط§ظ† ط§ظ„ط¥ط´ط¹ط§ط± ظˆظ†طµظ‡ ظ…ط·ظ„ظˆط¨ط§ظ†'
            ], 200);
        }

        $notification = Notification::create([
            'N_Title' => $title,
            'N_Message' => $message,
            'N_Type' => $type,
            'N_Date' => now()->format('Y-m-d'),
            'N_Time' => now()->format('H:i:s'),
            'N_Status' => 'ط؛ظٹط± ظ…ظ‚ط±ظˆط،',
            'Caregiver_ID' => $caregiverId,
            'Eldery_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… ط¥ظ†ط´ط§ط، ط§ظ„ط¥ط´ط¹ط§ط± ط¨ظ†ط¬ط§ط­',
            'data' => $notification
        ], 201);
    }
}

