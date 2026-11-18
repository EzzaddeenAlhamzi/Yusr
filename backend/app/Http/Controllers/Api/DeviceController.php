<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Support\YusrAccess;
use Illuminate\Http\Request;

class DeviceController extends Controller
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
                return YusrAccess::forbidden('غير مصرح بالوصول إلى أجهزة هذا الكبير في السن');
            }
            $scope = [$requested];
        } else {
            $scope = $allowed;
        }

        if ($scope === []) {
            $devices = collect();
        } else {
            $devices = Device::query()
                ->whereIn('Elderly_ID', $scope)
                ->orderBy('Devices_ID', 'desc')
                ->get();
        }

        return response()->json([
            'status' => 'success',
            'data' => $devices,
        ]);
    }

    public function store(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $type = trim($request->input('D_Type', 'ساعة ذكية'));
        $serial = trim($request->input('T_Number', ''));

        if (empty($serial)) {
            return response()->json([
                'status' => 'error',
                'message' => 'الرقم التسلسلي للجهاز مطلوب',
            ], 200);
        }

        $device = Device::create([
            'D_Type' => $type,
            'T_Number' => $serial,
            'Elderly_ID' => $gated,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تم ربط الجهاز بنجاح',
            'data' => $device,
        ], 201);
    }

    public function destroy($id = null, Request $request = null)
    {
        $request = $request ?? request();
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $deviceId = $id ?? $request->input('Devices_ID');
        $device = Device::find($deviceId);

        if (! $device) {
            return YusrAccess::notFound('الجهاز غير موجود');
        }

        if (! YusrAccess::canAccessElderly($actor, $device->Elderly_ID)) {
            return YusrAccess::forbidden('غير مصرح بحذف هذا الجهاز');
        }

        $device->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'تم حذف الجهاز بنجاح',
        ]);
    }
}
