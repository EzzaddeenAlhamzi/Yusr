<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Elderly;
use App\Support\YusrAccess;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Hash;

class ElderlyController extends Controller
{
    public function show(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $elderlyId = $id ?? $request->input('Eldery_ID', $request->query('Eldery_ID'));

        // No ID: return only accessible elderly rows (never full table dump).
        if ($elderlyId === null || $elderlyId === '') {
            $ids = YusrAccess::accessibleElderlyIds($actor);
            $data = $ids === []
                ? []
                : Elderly::query()->whereIn('Eldery_ID', $ids)->get();

            return response()->json([
                'status' => 'success',
                'data' => $data,
            ]);
        }

        $elderly = Elderly::find($elderlyId);
        if (! $elderly) {
            return YusrAccess::notFound('كبير السن غير موجود');
        }

        if (! Gate::forUser($actor)->allows('view', $elderly)) {
            return YusrAccess::forbidden('غير مصرح بعرض بيانات هذا الكبير في السن');
        }

        return response()->json([
            'status' => 'success',
            'data' => $elderly,
        ]);
    }

    public function update(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $elderlyId = $id ?? $request->input('Eldery_ID');
        $elderly = Elderly::find($elderlyId);

        if (! $elderly) {
            return YusrAccess::notFound('كبير السن غير موجود');
        }

        if (! Gate::forUser($actor)->allows('update', $elderly)) {
            return YusrAccess::forbidden('غير مصرح بتعديل بيانات هذا الكبير في السن');
        }

        $fields = [];
        if ($request->has('E_Name')) {
            $fields['E_Name'] = $request->input('E_Name');
        }
        if ($request->has('E_sex')) {
            $fields['E_sex'] = $request->input('E_sex');
        }
        if ($request->has('E_PhonNumber')) {
            $fields['E_PhonNumber'] = $request->input('E_PhonNumber');
        }
        if ($request->has('E_Email')) {
            $fields['E_Email'] = $request->input('E_Email');
        }
        // Password change: only the elderly account owner (role isolation).
        if ($request->has('E_Password') && ! empty($request->input('E_Password'))) {
            if (! ($actor instanceof Elderly) || (int) $actor->Eldery_ID !== (int) $elderly->Eldery_ID) {
                return YusrAccess::forbidden('لا يمكن لمقدم الرعاية تغيير كلمة مرور كبير السن من هذا المسار');
            }
            $fields['E_Password'] = Hash::make($request->input('E_Password'));
        }

        $elderly->update($fields);

        return response()->json([
            'status' => 'success',
            'message' => 'تم تحديث بيانات كبير السن بنجاح',
            'data' => $elderly->fresh(),
        ]);
    }

    public function linkCaregiver(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        // Role isolation: only caregivers may initiate link; force self ID.
        if (! ($actor instanceof Caregiver)) {
            return YusrAccess::forbidden('رمز كبير السن لا يمكنه ربط مقدمي رعاية');
        }

        $requestedCaregiverId = $request->input('Caregivers_ID');
        if ($requestedCaregiverId !== null && (int) $requestedCaregiverId !== (int) $actor->Caregivers_ID) {
            return YusrAccess::forbidden('لا يمكن ربط حساب مقدم رعاية آخر');
        }

        $elderlyId = $request->input('Eldery_ID', $request->input('Elderly_ID'));
        if (! $elderlyId) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'validation_error',
                'message' => 'معرف مقدم الرعاية ومعرف كبير السن مطلوبان',
            ], 200);
        }

        $elderly = Elderly::find($elderlyId);
        if (! $elderly) {
            return YusrAccess::notFound('مقدم الرعاية أو كبير السن غير موجود في قاعدة البيانات');
        }

        if (! Gate::forUser($actor)->allows('link', $elderly)) {
            return YusrAccess::forbidden('غير مصرح بربط هذا الحساب');
        }

        $actor->update(['Eldery_ID' => $elderly->Eldery_ID]);

        return response()->json([
            'status' => 'success',
            'message' => "تم ربط مقدم الرعاية ({$actor->C_Name}) بكبير السن ({$elderly->E_Name}) بنجاح!",
            'caregiver' => $actor->fresh(),
            'elderly' => $elderly,
        ]);
    }
}
