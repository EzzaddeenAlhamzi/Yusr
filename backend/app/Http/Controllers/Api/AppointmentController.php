<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Appointment;
use Illuminate\Http\Request;

class AppointmentController extends Controller
{
    public function index(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $query = Appointment::query();
        if ($elderlyId) {
            $query->where('Elderly_ID', $elderlyId);
        }

        $appointments = $query->orderBy('A_Date', 'asc')->orderBy('A_Time', 'asc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $appointments
        ]);
    }

    public function store(Request $request)
    {
        $dateType = trim($request->input('A_DateType', ''));
        $date = $request->input('A_Date');
        $time = $request->input('A_Time');
        $location = trim($request->input('A_Location', ''));
        $note = trim($request->input('A_Note', ''));
        $elderlyId = $request->input('Elderly_ID');

        if (empty($dateType) || empty($date)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظ†ظˆط¹ ط§ظ„ظ…ظˆط¹ط¯ ظˆطھط§ط±ظٹط®ظ‡ ظ…ط·ظ„ظˆط¨ط§ظ†'
            ], 200);
        }

        $appointment = Appointment::create([
            'A_Time' => $time,
            'A_Date' => $date,
            'A_DateType' => $dateType,
            'A_Location' => $location,
            'A_Note' => $note,
            'Elderly_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ…طھ ط¥ط¶ط§ظپط© ط§ظ„ظ…ظˆط¹ط¯ ط¨ظ†ط¬ط§ط­',
            'data' => $appointment
        ], 201);
    }

    public function destroy($id = null, Request $request = null)
    {
        $appointmentId = $id ?? ($request ? $request->input('Appointment_ID') : null);
        $appointment = Appointment::find($appointmentId);

        if (!$appointment) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ظ„ظ…ظˆط¹ط¯ ط؛ظٹط± ظ…ظˆط¬ظˆط¯'
            ], 200);
        }

        $appointment->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… ط­ط°ظپ ط§ظ„ظ…ظˆط¹ط¯ ط¨ظ†ط¬ط§ط­'
        ]);
    }
}

