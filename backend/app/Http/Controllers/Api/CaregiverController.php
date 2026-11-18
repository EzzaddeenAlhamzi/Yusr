<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Support\YusrAccess;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Hash;

class CaregiverController extends Controller
{
    public function show(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $caregiverId = $id ?? $request->input('Caregivers_ID', $request->query('Caregivers_ID'));
        $caregiver = Caregiver::find($caregiverId);

        if (! $caregiver) {
            return YusrAccess::notFound('مقدم الرعاية غير موجود');
        }

        if (! Gate::forUser($actor)->allows('view', $caregiver)) {
            return YusrAccess::forbidden('غير مصرح بعرض ملف مقدم الرعاية');
        }

        return response()->json([
            'status' => 'success',
            'data' => $caregiver,
        ]);
    }

    public function update(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $caregiverId = $id ?? $request->input('Caregivers_ID');
        $caregiver = Caregiver::find($caregiverId);

        if (! $caregiver) {
            return YusrAccess::notFound('مقدم الرعاية غير موجود');
        }

        if (! Gate::forUser($actor)->allows('update', $caregiver)) {
            return YusrAccess::forbidden('غير مصرح بتعديل ملف مقدم الرعاية');
        }

        $fields = [];
        if ($request->has('C_Name')) {
            $fields['C_Name'] = $request->input('C_Name');
        }
        if ($request->has('C_PhonNumber')) {
            $fields['C_PhonNumber'] = $request->input('C_PhonNumber');
        }
        if ($request->has('C_Relationship')) {
            $fields['C_Relationship'] = $request->input('C_Relationship');
        }
        if ($request->has('C_Email')) {
            $fields['C_Email'] = $request->input('C_Email');
        }
        if ($request->has('C_Password') && ! empty($request->input('C_Password'))) {
            $fields['C_Password'] = Hash::make($request->input('C_Password'));
        }

        // Never allow client to reassign Eldery_ID via update — use link endpoint.
        $caregiver->update($fields);

        return response()->json([
            'status' => 'success',
            'message' => 'تم تحديث بيانات مقدم الرعاية بنجاح',
            'data' => $caregiver->fresh(),
        ]);
    }
}
