<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Medication;
use App\Support\YusrAccess;
use Illuminate\Http\Request;

class MedicationController extends Controller
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
                return YusrAccess::forbidden('غير مصرح بالوصول إلى أدوية هذا الكبير في السن');
            }
            $scope = [$requested];
        } else {
            $scope = $allowed;
        }

        $query = Medication::query();
        if ($scope === []) {
            $medications = collect();
        } else {
            $medications = $query->whereIn('Elderly_ID', $scope)
                ->orderBy('Medicayion_ID', 'desc')
                ->get();
        }

        return response()->json([
            'status' => 'success',
            'data' => $medications,
        ]);
    }

    public function store(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $name = trim($request->input('M_Name', ''));
        $much = trim($request->input('M_much', ''));
        $repatTime = trim($request->input('M_RepatTime', ''));

        if (empty($name)) {
            return response()->json([
                'status' => 'error',
                'message' => 'اسم الدواء مطلوب',
            ], 200);
        }

        $medication = Medication::create([
            'M_Name' => $name,
            'M_much' => $much,
            'M_RepatTime' => $repatTime,
            'Elderly_ID' => $gated,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تمت إضافة الدواء بنجاح',
            'data' => $medication,
        ], 201);
    }

    public function update(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $medId = $id ?? $request->input('Medicayion_ID');
        $medication = Medication::find($medId);

        if (! $medication) {
            return YusrAccess::notFound('الدواء غير موجود');
        }

        if (! YusrAccess::canAccessElderly($actor, $medication->Elderly_ID)) {
            return YusrAccess::forbidden('غير مصرح بتعديل هذا الدواء');
        }

        $fields = [];
        if ($request->has('M_Name')) {
            $fields['M_Name'] = $request->input('M_Name');
        }
        if ($request->has('M_much')) {
            $fields['M_much'] = $request->input('M_much');
        }
        if ($request->has('M_RepatTime')) {
            $fields['M_RepatTime'] = $request->input('M_RepatTime');
        }

        $medication->update($fields);

        return response()->json([
            'status' => 'success',
            'message' => 'تم تحديث الدواء بنجاح',
            'data' => $medication,
        ]);
    }

    public function destroy($id = null, Request $request = null)
    {
        $request = $request ?? request();
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $medId = $id ?? $request->input('Medicayion_ID');
        $medication = Medication::find($medId);

        if (! $medication) {
            return YusrAccess::notFound('الدواء غير موجود');
        }

        if (! YusrAccess::canAccessElderly($actor, $medication->Elderly_ID)) {
            return YusrAccess::forbidden('غير مصرح بحذف هذا الدواء');
        }

        $medication->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'تم حذف الدواء بنجاح',
        ]);
    }
}
