<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EmergencyContact;
use App\Models\EmergencyLog;
use App\Support\YusrAccess;
use Illuminate\Http\Request;

class EmergencyController extends Controller
{
    public function getLogs(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $requested = YusrAccess::resolveElderlyId($request);
        $allowed = YusrAccess::accessibleElderlyIds($actor);

        if ($requested !== null) {
            if (! in_array($requested, $allowed, true)) {
                return YusrAccess::forbidden('غير مصرح بالوصول إلى بلاغات الطوارئ');
            }
            $scope = [$requested];
        } else {
            $scope = $allowed;
        }

        if ($scope === []) {
            $logs = collect();
        } else {
            $logs = EmergencyLog::with('elderly')
                ->whereIn('Elderly_ID', $scope)
                ->orderBy('Emergency_ID', 'desc')
                ->get();
        }

        return response()->json([
            'status' => 'success',
            'data' => $logs,
        ]);
    }

    public function storeLog(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $type = $request->input('E_Type');
        $location = $request->input('E_Location', 'موقع غير محدد');
        $lat = $request->input('latitude');
        $lng = $request->input('Longitude');
        $desc = $request->input('Descripion', 'نداء طوارئ عاجل من التطبيق');

        $log = EmergencyLog::create([
            'E_Type' => $type,
            'E_Time' => now()->format('H:i:s'),
            'E_Date' => now()->format('Y-m-d'),
            'E_Location' => $location,
            'latitude' => $lat,
            'Longitude' => $lng,
            'E_State' => 'نشط',
            'Descripion' => $desc,
            'Elderly_ID' => $gated,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تم تسجيل بلاغ الطوارئ بنجاح وإرساله فوراً لمقدم الرعاية',
            'data' => $log,
        ], 201);
    }

    public function updateStatus(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $emergencyId = $id ?? $request->input('Emergency_ID');
        $state = trim($request->input('E_State', ''));
        $note = trim($request->input('note', $request->input('Descripion', '')));

        if (! $emergencyId || empty($state)) {
            return response()->json([
                'status' => 'error',
                'message' => 'معرف البلاغ وحالة المتابعة الجديدة مطلوبان',
            ], 200);
        }

        $emergency = EmergencyLog::find($emergencyId);
        if (! $emergency) {
            return YusrAccess::notFound('بلاغ الطوارئ غير موجود في قاعدة البيانات');
        }

        if (! YusrAccess::canAccessElderly($actor, $emergency->Elderly_ID)) {
            return YusrAccess::forbidden('غير مصرح بتحديث حالة هذا البلاغ');
        }

        $updateData = ['E_State' => $state];
        if (! empty($note)) {
            $currentDesc = (string) $emergency->Descripion;
            $updateData['Descripion'] = $currentDesc . " [ملاحظة: {$note}]";
        }

        $emergency->update($updateData);

        return response()->json([
            'status' => 'success',
            'message' => "تم تحديث حالة البلاغ بنجاح إلى: {$state}",
            'data' => $emergency,
        ]);
    }

    public function getContacts(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $requested = YusrAccess::resolveElderlyId($request);
        $allowed = YusrAccess::accessibleElderlyIds($actor);

        if ($requested !== null) {
            if (! in_array($requested, $allowed, true)) {
                return YusrAccess::forbidden('غير مصرح بالوصول إلى جهات اتصال الطوارئ');
            }
            $scope = [$requested];
        } else {
            $scope = $allowed;
        }

        if ($scope === []) {
            $contacts = collect();
        } else {
            $contacts = EmergencyContact::query()
                ->whereIn('Eldery_ID', $scope)
                ->orderBy('Priority', 'asc')
                ->get();
        }

        return response()->json([
            'status' => 'success',
            'data' => $contacts,
        ]);
    }

    public function storeContact(Request $request)
    {
        $gated = YusrAccess::gateElderly(
            $request,
            YusrAccess::resolveElderlyId($request, $request->input('Eldery_ID')),
            true
        );
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $name = trim($request->input('contact_Name', ''));
        $phone = trim($request->input('Phone_Number', ''));
        $relationship = trim($request->input('Relationship', ''));
        $priority = $request->input('Priority', 1);

        if (empty($name) || empty($phone)) {
            return response()->json([
                'status' => 'error',
                'message' => 'اسم جهة الاتصال ورقم الهاتف مطلوبان',
            ], 200);
        }

        $contact = EmergencyContact::create([
            'contact_Name' => $name,
            'Phone_Number' => $phone,
            'Relationship' => $relationship,
            'Priority' => $priority,
            'Eldery_ID' => $gated,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تمت إضافة جهة اتصال الطوارئ بنجاح',
            'data' => $contact,
        ], 201);
    }

    public function destroyContact($id = null, Request $request = null)
    {
        $request = $request ?? request();
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $contactId = $id ?? $request->input('contact_ID');
        $contact = EmergencyContact::find($contactId);

        if (! $contact) {
            return YusrAccess::notFound('جهة الاتصال غير موجودة');
        }

        if (! YusrAccess::canAccessElderly($actor, $contact->Eldery_ID)) {
            return YusrAccess::forbidden('غير مصرح بحذف جهة الاتصال هذه');
        }

        $contact->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'تم حذف جهة اتصال الطوارئ بنجاح',
        ]);
    }
}
