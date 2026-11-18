<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Support\YusrAccess;
use Illuminate\Http\Request;

class AppointmentController extends Controller
{
    public function index(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $requested = YusrAccess::resolveElderlyId($request);
        $allowed = YusrAccess::accessibleElderlyIds($actor);

        if ($requested !== null) {
            if (! in_array($requested, $allowed, true)) {
                return YusrAccess::forbidden('غير مصرح بالوصول إلى مواعيد هذا الكبير في السن');
            }
            $scope = [$requested];
        } else {
            $scope = $allowed;
        }

        if ($scope === []) {
            $appointments = collect();
        } else {
            $appointments = Appointment::query()
                ->whereIn('Elderly_ID', $scope)
                ->orderBy('A_Date', 'asc')
                ->orderBy('A_Time', 'asc')
                ->get();
        }

        return response()->json([
            'status' => 'success',
            'data' => $appointments,
        ]);
    }

    public function store(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $dateType = trim($request->input('A_DateType', ''));
        $date = $request->input('A_Date');
        $time = $request->input('A_Time');
        $location = trim($request->input('A_Location', ''));
        $note = trim($request->input('A_Note', ''));

        if (empty($dateType) || empty($date)) {
            return response()->json([
                'status' => 'error',
                'message' => 'نوع الموعد وتاريخه مطلوبان',
            ], 200);
        }

        $appointment = Appointment::create([
            'A_Time' => $time,
            'A_Date' => $date,
            'A_DateType' => $dateType,
            'A_Location' => $location,
            'A_Note' => $note,
            'Elderly_ID' => $gated,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تمت إضافة الموعد بنجاح',
            'data' => $appointment,
        ], 201);
    }

    public function destroy($id = null, Request $request = null)
    {
        $request = $request ?? request();
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $appointmentId = $id ?? $request->input('Appointment_ID');
        $appointment = Appointment::find($appointmentId);

        if (! $appointment) {
            return YusrAccess::notFound('الموعد غير موجود');
        }

        if (! YusrAccess::canAccessElderly($actor, $appointment->Elderly_ID)) {
            return YusrAccess::forbidden('غير مصرح بحذف هذا الموعد');
        }

        $appointment->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'تم حذف الموعد بنجاح',
        ]);
    }
}
