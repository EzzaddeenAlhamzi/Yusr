<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Appointment;
use App\Support\YusrAccess;
use Illuminate\Http\JsonResponse;
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

        $dateError = $this->validateAppointmentDate($date);
        if ($dateError !== null) {
            return $dateError;
        }

        $timeError = $this->validateAppointmentTime($time);
        if ($timeError !== null) {
            return $timeError;
        }

        try {
            $appointment = Appointment::create([
                'A_Time' => $time,
                'A_Date' => $date,
                'A_DateType' => $dateType,
                'A_Location' => $location,
                'A_Note' => $note,
                'Elderly_ID' => $gated,
            ]);
        } catch (\Throwable $e) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'save_failed',
                'message' => 'تعذّر حفظ الموعد على الخادم',
            ], 200);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تمت إضافة الموعد بنجاح',
            'data' => $appointment,
        ], 201);
    }

    /**
     * Update an existing appointment in place (same Appointment_ID).
     * Editable: A_DateType, A_Date, A_Time, A_Location, A_Note.
     * Elderly_ID (owner) is immutable — rejected if client attempts change.
     */
    public function update(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $appointmentId = $id ?? $request->input('Appointment_ID');
        $appointment = Appointment::find($appointmentId);

        if (! $appointment) {
            return YusrAccess::notFound('الموعد غير موجود');
        }

        if (! YusrAccess::canAccessElderly($actor, $appointment->Elderly_ID)
            || ! $actor->can('update', $appointment)) {
            return YusrAccess::forbidden('غير مصرح بتعديل هذا الموعد');
        }

        // Reject ownership reassignment (PO-P15-05 / PO rule 3).
        if ($request->exists('Elderly_ID') || $request->exists('Eldery_ID') || $request->exists('elderly_id')) {
            $attempted = YusrAccess::resolveElderlyId($request);
            if ($attempted !== null && $attempted !== (int) $appointment->Elderly_ID) {
                return response()->json([
                    'status' => 'error',
                    'error_type' => 'ownership_immutable',
                    'message' => 'لا يمكن تغيير مالك الموعد',
                ], 422);
            }
        }

        $fields = [];

        if ($request->exists('A_DateType')) {
            $dateType = trim((string) $request->input('A_DateType', ''));
            if ($dateType === '') {
                return response()->json([
                    'status' => 'error',
                    'error_type' => 'validation',
                    'message' => 'نوع الموعد مطلوب',
                ], 422);
            }
            $fields['A_DateType'] = $dateType;
        }

        if ($request->exists('A_Date')) {
            $date = $request->input('A_Date');
            $dateError = $this->validateAppointmentDate($date, 422);
            if ($dateError !== null) {
                return $dateError;
            }
            $fields['A_Date'] = $date;
        }

        if ($request->exists('A_Time')) {
            $time = $request->input('A_Time');
            $timeError = $this->validateAppointmentTime($time, 422);
            if ($timeError !== null) {
                return $timeError;
            }
            $fields['A_Time'] = $time;
        }

        if ($request->exists('A_Location')) {
            $fields['A_Location'] = trim((string) $request->input('A_Location', ''));
        }

        if ($request->exists('A_Note')) {
            $fields['A_Note'] = trim((string) $request->input('A_Note', ''));
        }

        if ($fields === []) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'validation',
                'message' => 'لا توجد حقول قابلة للتعديل في الطلب',
            ], 422);
        }

        try {
            $appointment->update($fields);
            $appointment->refresh();
        } catch (\Throwable $e) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'save_failed',
                'message' => 'تعذّر حفظ تعديل الموعد على الخادم',
            ], 422);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم تحديث الموعد بنجاح',
            'data' => $appointment,
        ]);
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

        if (! $actor->can('delete', $appointment)) {
            return YusrAccess::forbidden('غير مصرح بحذف هذا الموعد');
        }

        $appointment->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'تم حذف الموعد بنجاح',
        ]);
    }

    /**
     * Reject impossible calendar dates before MySQL (avoids SQLSTATE[22007] 500).
     */
    private function validateAppointmentDate(mixed $date, int $status = 200): ?JsonResponse
    {
        if (! is_string($date) || ! preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'invalid_date',
                'message' => 'تاريخ الموعد غير صالح. استخدم صيغة YYYY-MM-DD صحيحة.',
            ], $status);
        }
        [$year, $month, $day] = array_map('intval', explode('-', $date));
        if (! checkdate($month, $day, $year)) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'invalid_date',
                'message' => 'تاريخ الموعد غير صالح. استخدم صيغة YYYY-MM-DD صحيحة.',
            ], $status);
        }

        return null;
    }

    /**
     * Accept null/empty, HH:MM, or HH:MM:SS. Reject other shapes.
     */
    private function validateAppointmentTime(mixed $time, int $status = 200): ?JsonResponse
    {
        if ($time === null || $time === '') {
            return null;
        }
        if (! is_string($time) && ! is_numeric($time)) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'invalid_time',
                'message' => 'وقت الموعد غير صالح. استخدم صيغة HH:MM أو HH:MM:SS.',
            ], $status);
        }
        $time = (string) $time;
        if (! preg_match('/^([01]\d|2[0-3]):([0-5]\d)(:([0-5]\d))?$/', $time)) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'invalid_time',
                'message' => 'وقت الموعد غير صالح. استخدم صيغة HH:MM أو HH:MM:SS.',
            ], $status);
        }

        return null;
    }
}
