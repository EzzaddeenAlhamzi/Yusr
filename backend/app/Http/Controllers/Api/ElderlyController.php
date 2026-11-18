<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Elderly;
use App\Support\LinkingCodeService;
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

        $payload = $elderly->toArray();
        // Self-view: include linked caregiver (used by elderly pairing-status UI).
        if ($actor instanceof Elderly && (int) $actor->Eldery_ID === (int) $elderly->Eldery_ID) {
            $payload['caregiver'] = Caregiver::query()
                ->where('Eldery_ID', $elderly->Eldery_ID)
                ->first();
        }

        return response()->json([
            'status' => 'success',
            'data' => $payload,
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

    /**
     * Elderly generates a temporary 6-digit linking code (hash stored server-side).
     * Never generates for another elderly via client-supplied ID.
     */
    public function generateLinkingCode(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        if (! ($actor instanceof Elderly)) {
            return YusrAccess::forbidden('رمز مقدم الرعاية لا يمكنه إنشاء رمز ربط لكبير السن');
        }

        // Ignore any client-supplied Eldery_ID — always self.
        $result = LinkingCodeService::generateForElderly($actor);
        if ($result instanceof \Illuminate\Http\JsonResponse) {
            return $result;
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم إنشاء رمز الربط بنجاح',
            'data' => [
                'linking_code' => $result['code'],
                'expires_at' => $result['expires_at'],
                'expires_in_seconds' => $result['expires_in_seconds'],
            ],
        ]);
    }

    /**
     * Caregiver links via temporary linking_code only.
     * Direct Eldery_ID / Elderly_ID linking is blocked (REST + legacy).
     */
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

        // Block direct-ID link bypass (consent must be a temporary code).
        $hasDirectId = $request->filled('Eldery_ID') || $request->filled('Elderly_ID');
        $linkingCode = $request->input('linking_code', $request->input('code'));

        if ($hasDirectId && ($linkingCode === null || $linkingCode === '')) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'forbidden',
                'message' => 'الربط المباشر بمعرف كبير السن غير مسموح. استخدم رمز الربط المؤقت.',
            ], 403);
        }

        if ($linkingCode === null || $linkingCode === '') {
            return response()->json([
                'status' => 'error',
                'error_type' => 'validation_error',
                'message' => 'رمز الربط المكون من 6 أرقام مطلوب',
            ], 200);
        }

        $result = LinkingCodeService::consumeAndLink(
            $actor,
            (string) $linkingCode,
            $request->ip()
        );

        if ($result instanceof \Illuminate\Http\JsonResponse) {
            return $result;
        }

        /** @var Caregiver $caregiver */
        $caregiver = $result['caregiver'];
        /** @var Elderly $elderly */
        $elderly = $result['elderly'];

        return response()->json([
            'status' => 'success',
            'message' => "تم ربط مقدم الرعاية ({$caregiver->C_Name}) بكبير السن ({$elderly->E_Name}) بنجاح!",
            'caregiver' => $caregiver,
            'elderly' => $elderly,
        ]);
    }
}
