<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\Medication;
use App\Models\MedicationDoseOccurrence;
use App\Services\MedicationAdherenceService;
use App\Support\YusrAccess;
use Carbon\Carbon;
use Illuminate\Http\Request;

class MedicationController extends Controller
{
    public function __construct(
        protected MedicationAdherenceService $adherence
    ) {
    }

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

    /**
     * P2.2 — today's scheduled doses (server SoT). Materializes within 1-day horizon.
     * Caregiver + elderly linked/self may read.
     */
    public function todayDoses(Request $request)
    {
        if (! $this->adherence->tablesReady()) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'schema_missing',
                'message' => 'جداول الالتزام غير جاهزة على الخادم',
            ], 200);
        }

        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $civilDate = trim((string) $request->input('civil_date', $request->query('civil_date', '')));
        if ($civilDate === '') {
            $civilDate = Carbon::now()->format('Y-m-d');
        }
        if (! preg_match('/^\d{4}-\d{2}-\d{2}$/', $civilDate)) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'validation_error',
                'message' => 'صيغة التاريخ المدني غير صالحة (YYYY-MM-DD)',
            ], 200);
        }

        $now = $this->resolveNow($request);
        $this->adherence->ensureOccurrencesForDates((int) $gated, [$civilDate], $now);

        $occurrences = MedicationDoseOccurrence::query()
            ->with('medication')
            ->where('Elderly_ID', $gated)
            ->whereDate('scheduled_date', $civilDate)
            ->orderBy('scheduled_time')
            ->orderBy('Medicayion_ID')
            ->get();

        $data = $this->adherence->serializeOccurrences($occurrences, $now);

        return response()->json([
            'status' => 'success',
            'data' => $data,
            'meta' => [
                'civil_date' => $civilDate,
                'grace_minutes' => MedicationAdherenceService::GRACE_MINUTES,
                'source_of_truth' => 'server',
                'offline_pending_sync' => false,
                'caregiver_confirm' => false,
                'notification_scheduler' => 'deferred_P2.3',
            ],
        ]);
    }

    /**
     * P2.2 — adherence history (confirmed + unconfirmed within horizon).
     * Linked caregiver READ-ONLY; elderly self OK.
     */
    public function adherenceHistory(Request $request)
    {
        if (! $this->adherence->tablesReady()) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'schema_missing',
                'message' => 'جداول الالتزام غير جاهزة على الخادم',
            ], 200);
        }

        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $range = $this->adherence->clampHistoryRange(
            $request->input('from', $request->query('from')),
            $request->input('to', $request->query('to')),
            $this->resolveNow($request)
        );
        if ($range === null) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'validation_error',
                'message' => 'نطاق التاريخ غير صالح',
            ], 200);
        }

        [$from, $to] = $range;
        $now = $this->resolveNow($request);
        $dates = $this->adherence->dateSpan($from, $to);
        $this->adherence->ensureOccurrencesForDates((int) $gated, $dates, $now);

        $occurrences = MedicationDoseOccurrence::query()
            ->with('medication')
            ->where('Elderly_ID', $gated)
            ->whereDate('scheduled_date', '>=', $from)
            ->whereDate('scheduled_date', '<=', $to)
            ->orderBy('scheduled_date', 'desc')
            ->orderBy('scheduled_time', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $this->adherence->serializeOccurrences($occurrences, $now),
            'meta' => [
                'from' => $from,
                'to' => $to,
                'max_history_days' => MedicationAdherenceService::MAX_HISTORY_DAYS,
                'source_of_truth' => 'server',
                'caregiver_write' => false,
            ],
        ]);
    }

    /**
     * P2.2 — elderly confirm dose (online-only SoT). Caregivers are READ-ONLY → 403.
     * Idempotent on duplicate confirm / client_confirm_id retry.
     */
    public function confirmDose(Request $request)
    {
        if (! $this->adherence->tablesReady()) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'schema_missing',
                'message' => 'جداول الالتزام غير جاهزة على الخادم',
            ], 200);
        }

        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        if ($actor instanceof Caregiver) {
            return YusrAccess::forbidden(
                'تأكيد الجرعة متاح لكبير السن فقط. المرافق يمكنه الاطلاع فقط.'
            );
        }

        if (! ($actor instanceof Elderly)) {
            return YusrAccess::unauthenticated();
        }

        $medId = $request->input('Medicayion_ID', $request->input('medication_id'));
        if ($medId === null || $medId === '') {
            return response()->json([
                'status' => 'error',
                'error_type' => 'validation_error',
                'message' => 'معرف الدواء مطلوب',
            ], 200);
        }

        $medication = Medication::find($medId);
        if (! $medication) {
            return YusrAccess::notFound('الدواء غير موجود');
        }

        if ((int) $medication->Elderly_ID !== (int) $actor->Eldery_ID) {
            return YusrAccess::forbidden('غير مصرح بتأكيد جرعة لا تخصك');
        }

        $civilDate = trim((string) $request->input('civil_date', ''));
        if ($civilDate === '') {
            $civilDate = Carbon::now()->format('Y-m-d');
        }
        if (! preg_match('/^\d{4}-\d{2}-\d{2}$/', $civilDate)) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'validation_error',
                'message' => 'صيغة التاريخ المدني غير صالحة (YYYY-MM-DD)',
            ], 200);
        }

        $occurrenceKey = $request->input('occurrence_key');
        $occurrenceKey = is_string($occurrenceKey) && $occurrenceKey !== ''
            ? $occurrenceKey
            : null;

        $clientConfirmId = $request->input('client_confirm_id');
        $clientConfirmId = is_string($clientConfirmId) && $clientConfirmId !== ''
            ? substr($clientConfirmId, 0, 64)
            : null;

        $result = $this->adherence->confirmDose(
            $medication,
            $actor,
            $civilDate,
            $occurrenceKey,
            $clientConfirmId,
            $this->resolveNow($request)
        );

        if (! $result['ok']) {
            $status = ($result['code'] ?? '') === 'idempotency_conflict' ? 409 : 200;

            return response()->json([
                'status' => 'error',
                'error_type' => $result['code'] ?? 'confirm_failed',
                'message' => $result['message'] ?? 'تعذّر تأكيد الجرعة',
            ], $status);
        }

        /** @var MedicationDoseOccurrence $occ */
        $occ = $result['occurrence'];
        $serialized = $this->adherence->serializeOccurrences(
            [$occ->loadMissing('medication')],
            $this->resolveNow($request)
        );

        return response()->json([
            'status' => 'success',
            'message' => ($result['idempotent'] ?? false)
                ? 'تم تأكيد الجرعة مسبقاً'
                : 'تم تأكيد تناول الدواء بنجاح',
            'data' => $serialized[0] ?? null,
            'meta' => [
                'idempotent' => (bool) ($result['idempotent'] ?? false),
                'source_of_truth' => 'server',
                'grace_minutes' => MedicationAdherenceService::GRACE_MINUTES,
            ],
        ]);
    }

    /**
     * Allow tests to pin clock via X-Test-Now header (ignored outside testing).
     */
    private function resolveNow(Request $request): Carbon
    {
        if (app()->environment('testing')) {
            $pinned = $request->header('X-Test-Now', $request->input('_test_now'));
            if (is_string($pinned) && $pinned !== '') {
                return Carbon::parse($pinned);
            }
        }

        return Carbon::now();
    }
}
