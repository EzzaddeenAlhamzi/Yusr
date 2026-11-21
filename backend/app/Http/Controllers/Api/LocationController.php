<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\LocationTracking;
use App\Models\SafeZone;
use App\Services\SafeZoneAlertService;
use App\Support\YusrAccess;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;

class LocationController extends Controller
{
    public function __construct(
        private readonly SafeZoneAlertService $geofenceAlerts
    ) {
    }

    public function sharingStatus(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $enabled = $this->isSharingEnabled((int) $gated);

        return response()->json([
            'status' => 'success',
            'data' => [
                'Elderly_ID' => (int) $gated,
                'location_sharing_enabled' => $enabled,
                'sharing_enabled' => $enabled,
            ],
        ]);
    }

    public function setSharing(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        // Only the elderly account may grant/revoke informed consent.
        if (! ($actor instanceof Elderly)) {
            return YusrAccess::forbidden('موافقة مشاركة الموقع ملك لكبير السن فقط');
        }

        $gated = YusrAccess::gateElderly($request, (int) $actor->Eldery_ID, true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        if ((int) $gated !== (int) $actor->Eldery_ID) {
            return YusrAccess::forbidden('لا يمكن تغيير موافقة مسن آخر');
        }

        $raw = $request->input('location_sharing_enabled', $request->input('sharing_enabled'));
        if ($raw === null) {
            return response()->json([
                'status' => 'error',
                'message' => 'قيمة مشاركة الموقع مطلوبة',
            ], 422);
        }

        $enabled = filter_var($raw, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($enabled === null) {
            $enabled = in_array((string) $raw, ['1', 'true', 'yes', 'on'], true);
        }

        if (! Schema::hasColumn('elderly', 'location_sharing_enabled')) {
            return response()->json([
                'status' => 'error',
                'message' => 'عمود مشاركة الموقع غير متوفر — طبّق الهجرة',
            ], 500);
        }

        $actor->location_sharing_enabled = (bool) $enabled;
        $actor->save();

        return response()->json([
            'status' => 'success',
            'message' => $enabled
                ? 'تم تفعيل مشاركة الموقع'
                : 'تم إيقاف مشاركة الموقع',
            'data' => [
                'Elderly_ID' => (int) $actor->Eldery_ID,
                'location_sharing_enabled' => (bool) $actor->location_sharing_enabled,
                'sharing_enabled' => (bool) $actor->location_sharing_enabled,
            ],
        ]);
    }

    public function current(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $actor = YusrAccess::actor($request);
        $sharing = $this->isSharingEnabled((int) $gated);

        // Caregivers must not receive protected coordinates when sharing is off.
        if ($actor instanceof Caregiver && ! $sharing) {
            return response()->json([
                'status' => 'success',
                'sharing_enabled' => false,
                'freshness' => 'sharing_stopped',
                'message' => 'مشاركة الموقع متوقفة',
                'data' => null,
            ]);
        }

        $location = LocationTracking::where('Elderly_ID', $gated)
            ->orderBy('Location_ID', 'desc')
            ->first();

        if ($location) {
            $data = $this->serializeLocation($location);
        } else {
            $data = null;
        }

        return response()->json([
            'status' => 'success',
            'sharing_enabled' => $sharing,
            'freshness' => $this->freshnessLabel($location?->L_UpdateTime),
            'data' => $data,
        ]);
    }

    public function store(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        // Publishing GPS is elderly-device only.
        if (! ($actor instanceof Elderly)) {
            return YusrAccess::forbidden('نشر الموقع متاح لحساب كبير السن فقط');
        }

        $gated = YusrAccess::gateElderly($request, (int) $actor->Eldery_ID, true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        if ((int) $gated !== (int) $actor->Eldery_ID) {
            return YusrAccess::forbidden('لا يمكن نشر موقع لحساب آخر');
        }

        if (! $this->isSharingEnabled((int) $gated)) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'sharing_disabled',
                'message' => 'مشاركة الموقع متوقفة — فعّل الموافقة أولاً',
                'sharing_enabled' => false,
            ], 403);
        }

        $lat = $request->input('L_Latitude', $request->input('latitude'));
        $lng = $request->input('L_Longitude', $request->input('Longitude', $request->input('longitude')));
        $accuracy = $request->input(
            'L_AccuracyMeters',
            $request->input('accuracy_meters', $request->input('accuracy'))
        );

        if ($lat === null || $lng === null || $lat === '' || $lng === '') {
            return response()->json([
                'status' => 'error',
                'message' => 'بيانات الموقع ومعرف كبير السن مطلوبة',
            ], 422);
        }

        $lat = (float) $lat;
        $lng = (float) $lng;
        if (! is_finite($lat) || ! is_finite($lng) || abs($lat) > 90 || abs($lng) > 180) {
            return response()->json([
                'status' => 'error',
                'message' => 'إحداثيات غير صالحة',
            ], 422);
        }

        $accuracyMeters = null;
        if ($accuracy !== null && $accuracy !== '') {
            $accuracyMeters = (float) $accuracy;
            if (! is_finite($accuracyMeters) || $accuracyMeters < 0) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'دقة الموقع غير صالحة',
                ], 422);
            }
        }

        // Client must not invent privileged event IDs; ignore any client event keys.
        $payload = [
            'L_Latitude' => $lat,
            'L_Longitude' => $lng,
            'L_UpdateTime' => now(),
            'Elderly_ID' => $gated,
        ];

        // Store real meters in L_AccuracyMeters; keep L_Scor as rounded meters for legacy UI
        // only when accuracy is known — never fabricate 100%.
        if ($accuracyMeters !== null) {
            $payload['L_AccuracyMeters'] = round($accuracyMeters, 2);
            $payload['L_Scor'] = (int) max(0, round($accuracyMeters));
        } else {
            $payload['L_Scor'] = null;
            if (Schema::hasColumn('location_tracking', 'L_AccuracyMeters')) {
                $payload['L_AccuracyMeters'] = null;
            }
        }

        $location = LocationTracking::create($payload);

        $geofence = ['evaluated' => 0, 'events' => 0, 'alerts' => 0];
        try {
            $geofence = $this->geofenceAlerts->evaluateFix(
                (int) $gated,
                $lat,
                $lng,
                $accuracyMeters
            );
        } catch (\Throwable $e) {
            // Location persist must succeed even if geofence evaluation fails.
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم تحديث الموقع الجغرافي بنجاح',
            'data' => $this->serializeLocation($location),
            'geofence' => $geofence,
        ], 201);
    }

    public function history(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $actor = YusrAccess::actor($request);
        $sharing = $this->isSharingEnabled((int) $gated);

        if ($actor instanceof Caregiver && ! $sharing) {
            return response()->json([
                'status' => 'success',
                'sharing_enabled' => false,
                'message' => 'مشاركة الموقع متوقفة',
                'data' => [],
            ]);
        }

        $cutoff = Carbon::now()->subDays(7)->toDateTimeString();

        $locations = LocationTracking::where('Elderly_ID', $gated)
            ->where(function ($q) use ($cutoff) {
                $q->whereNull('L_UpdateTime')
                    ->orWhere('L_UpdateTime', '>=', $cutoff);
            })
            ->orderBy('Location_ID', 'desc')
            ->limit(100)
            ->get()
            ->map(fn ($row) => $this->serializeLocation($row))
            ->values();

        return response()->json([
            'status' => 'success',
            'sharing_enabled' => $sharing,
            'retention_days' => 7,
            'data' => $locations,
        ]);
    }

    public function getSafeZones(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $actor = YusrAccess::actor($request);
        $sharing = $this->isSharingEnabled((int) $gated);

        // HIGH-1 / L4: caregivers must not receive zone center/radius while sharing is off.
        // Elderly owner may still list/manage own zones without sharing enabled.
        if ($actor instanceof Caregiver && ! $sharing) {
            return response()->json([
                'status' => 'success',
                'sharing_enabled' => false,
                'message' => 'مشاركة الموقع متوقفة',
                'data' => [],
            ]);
        }

        $zones = SafeZone::where('Zldery_ID', $gated)
            ->orderBy('Zone_ID', 'desc')
            ->get()
            ->map(fn ($z) => $this->serializeZone($z))
            ->values();

        return response()->json([
            'status' => 'success',
            'sharing_enabled' => $sharing,
            'data' => $zones,
        ]);
    }

    public function storeSafeZone(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $parsed = $this->parseZoneInput($request);
        if ($parsed instanceof \Illuminate\Http\JsonResponse) {
            return $parsed;
        }

        $now = now();
        $isElderly = $actor instanceof Elderly;
        $isCaregiver = $actor instanceof Caregiver;

        if ($isElderly && (int) $actor->Eldery_ID !== (int) $gated) {
            return YusrAccess::forbidden('لا يمكن إنشاء منطقة لمسن آخر');
        }

        $zone = new SafeZone();
        $zone->Z_Name = $parsed['name'];
        $zone->center_lat = $parsed['lat'];
        $zone->center_lng = $parsed['lng'];
        $zone->radius_meters = $parsed['radius'];
        $zone->Z_Limit = $parsed['radius']; // legacy mirror
        $zone->Zldery_ID = (int) $gated;
        $zone->created_at = $now;
        $zone->updated_at = $now;

        if ($isElderly) {
            $zone->created_by_role = 'elderly';
            $zone->created_by_caregiver_id = null;
            $zone->approval_status = 'approved';
            $zone->Z_state = 'active';
            $zone->activated_at = $now;
        } elseif ($isCaregiver) {
            $zone->created_by_role = 'caregiver';
            $zone->created_by_caregiver_id = (int) $actor->Caregivers_ID;
            $zone->approval_status = 'pending';
            $zone->Z_state = 'pending';
            $zone->activated_at = null;
        } else {
            return YusrAccess::forbidden();
        }

        $zone->save();

        return response()->json([
            'status' => 'success',
            'message' => $isElderly
                ? 'تم إنشاء المنطقة الآمنة وتفعيلها'
                : 'تم اقتراح المنطقة — بانتظار موافقة كبير السن',
            'data' => $this->serializeZone($zone->fresh()),
        ], 201);
    }

    public function updateSafeZone(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $zoneId = (int) ($id ?? $request->input('Zone_ID') ?? $request->input('zone_id') ?? 0);
        $zone = SafeZone::query()->where('Zone_ID', $zoneId)->first();
        if (! $zone) {
            return YusrAccess::notFound('المنطقة غير موجودة');
        }

        $gated = YusrAccess::gateElderly($request, (int) $zone->Zldery_ID, true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $material = $request->hasAny([
            'center_lat', 'center_lng', 'latitude', 'longitude',
            'L_Latitude', 'L_Longitude', 'radius_meters', 'Z_Limit', 'radius',
            'Z_Name', 'name',
        ]);

        // Caregiver material edits become a pending proposal (cannot self-activate).
        // Approved active geometry stays until elderly approves the replacement.
        if ($actor instanceof Caregiver) {
            if ($material) {
                $parsed = $this->parseZoneInput($request, allowPartial: true, existing: $zone);
                if ($parsed instanceof \Illuminate\Http\JsonResponse) {
                    return $parsed;
                }

                $isApprovedActive = $zone->approval_status === 'approved'
                    && in_array((string) $zone->Z_state, ['active', 'Active', 'نشط'], true);

                if ($isApprovedActive) {
                    // Keep original row active; upsert a separate pending proposal.
                    $proposal = SafeZone::query()
                        ->where('Zldery_ID', (int) $zone->Zldery_ID)
                        ->where('replaces_zone_id', (int) $zone->Zone_ID)
                        ->where('approval_status', 'pending')
                        ->first();

                    if (! $proposal) {
                        $proposal = new SafeZone();
                        $proposal->Zldery_ID = (int) $zone->Zldery_ID;
                        $proposal->replaces_zone_id = (int) $zone->Zone_ID;
                        $proposal->created_at = now();
                        $proposal->created_by_role = 'caregiver';
                        $proposal->created_by_caregiver_id = (int) $actor->Caregivers_ID;
                        $proposal->approval_status = 'pending';
                        $proposal->Z_state = 'pending';
                        $proposal->activated_at = null;
                    }

                    $proposal->Z_Name = $parsed['name'];
                    $proposal->center_lat = $parsed['lat'];
                    $proposal->center_lng = $parsed['lng'];
                    $proposal->radius_meters = $parsed['radius'];
                    $proposal->Z_Limit = $parsed['radius'];
                    $proposal->updated_at = now();
                    $proposal->save();

                    return response()->json([
                        'status' => 'success',
                        'message' => 'تم اقتراح تعديل المنطقة — المنطقة الحالية تبقى نشطة حتى موافقة كبير السن',
                        'data' => $this->serializeZone($proposal->fresh()),
                        'active_zone' => $this->serializeZone($zone->fresh()),
                    ]);
                }

                // Pending / non-active rows may be updated in place as proposals.
                $zone->Z_Name = $parsed['name'];
                $zone->center_lat = $parsed['lat'];
                $zone->center_lng = $parsed['lng'];
                $zone->radius_meters = $parsed['radius'];
                $zone->Z_Limit = $parsed['radius'];
                $zone->approval_status = 'pending';
                $zone->Z_state = 'pending';
                $zone->activated_at = null;
                $zone->created_by_role = 'caregiver';
                $zone->created_by_caregiver_id = (int) $actor->Caregivers_ID;
                $zone->updated_at = now();
                $zone->save();

                return response()->json([
                    'status' => 'success',
                    'message' => 'تم اقتراح تعديل المنطقة — بانتظار موافقة كبير السن',
                    'data' => $this->serializeZone($zone->fresh()),
                ]);
            }

            return YusrAccess::forbidden('تعديل المنطقة المادية يتطلب موافقة كبير السن');
        }

        if (! ($actor instanceof Elderly) || (int) $actor->Eldery_ID !== (int) $zone->Zldery_ID) {
            return YusrAccess::forbidden();
        }

        if ($material) {
            $parsed = $this->parseZoneInput($request, allowPartial: true, existing: $zone);
            if ($parsed instanceof \Illuminate\Http\JsonResponse) {
                return $parsed;
            }
            $zone->Z_Name = $parsed['name'];
            $zone->center_lat = $parsed['lat'];
            $zone->center_lng = $parsed['lng'];
            $zone->radius_meters = $parsed['radius'];
            $zone->Z_Limit = $parsed['radius'];
        }

        if ($request->has('Z_state') || $request->has('active')) {
            $active = filter_var(
                $request->input('active', $request->input('Z_state')),
                FILTER_VALIDATE_BOOLEAN,
                FILTER_NULL_ON_FAILURE
            );
            if ($active === true || in_array((string) $request->input('Z_state'), ['active', 'Active', 'نشط'], true)) {
                if ($zone->approval_status !== 'approved') {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'لا يمكن تفعيل منطقة غير معتمدة',
                    ], 422);
                }
                $zone->Z_state = 'active';
                $zone->activated_at = $zone->activated_at ?: now();
            } elseif ($active === false || in_array((string) $request->input('Z_state'), ['inactive', 'Inactive', 'متوقف'], true)) {
                $zone->Z_state = 'inactive';
            }
        }

        $zone->updated_at = now();
        $zone->save();

        return response()->json([
            'status' => 'success',
            'message' => 'تم تحديث المنطقة الآمنة',
            'data' => $this->serializeZone($zone->fresh()),
        ]);
    }

    public function destroySafeZone(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        if (! ($actor instanceof Elderly)) {
            return YusrAccess::forbidden('حذف المنطقة متاح لكبير السن فقط');
        }

        $zoneId = (int) ($id ?? $request->input('Zone_ID') ?? $request->input('zone_id') ?? 0);
        $zone = SafeZone::query()->where('Zone_ID', $zoneId)->first();
        if (! $zone) {
            return YusrAccess::notFound('المنطقة غير موجودة');
        }

        if ((int) $zone->Zldery_ID !== (int) $actor->Eldery_ID) {
            return YusrAccess::forbidden();
        }

        $zone->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'تم حذف المنطقة الآمنة',
        ]);
    }

    public function approveSafeZone(Request $request, $id = null)
    {
        return $this->resolveZoneApproval($request, $id, approve: true);
    }

    public function rejectSafeZone(Request $request, $id = null)
    {
        return $this->resolveZoneApproval($request, $id, approve: false);
    }

    private function resolveZoneApproval(Request $request, $id, bool $approve)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        if (! ($actor instanceof Elderly)) {
            return YusrAccess::forbidden('اعتماد المنطقة ملك لكبير السن فقط');
        }

        $zoneId = (int) ($id ?? $request->input('Zone_ID') ?? $request->input('zone_id') ?? 0);
        $zone = SafeZone::query()->where('Zone_ID', $zoneId)->first();
        if (! $zone) {
            return YusrAccess::notFound('المنطقة غير موجودة');
        }

        if ((int) $zone->Zldery_ID !== (int) $actor->Eldery_ID) {
            return YusrAccess::forbidden();
        }

        if ($zone->approval_status !== 'pending') {
            return response()->json([
                'status' => 'error',
                'message' => 'لا توجد مقترحات معلّقة لهذه المنطقة',
            ], 422);
        }

        if ($approve) {
            $replacesId = $zone->replaces_zone_id !== null ? (int) $zone->replaces_zone_id : 0;
            if ($replacesId > 0) {
                $target = SafeZone::query()->where('Zone_ID', $replacesId)->first();
                if (! $target || (int) $target->Zldery_ID !== (int) $actor->Eldery_ID) {
                    return YusrAccess::notFound('المنطقة الأصلية غير موجودة');
                }
                // Atomic replace: copy proposal geometry onto the active zone.
                $target->Z_Name = $zone->Z_Name;
                $target->center_lat = $zone->center_lat;
                $target->center_lng = $zone->center_lng;
                $target->radius_meters = $zone->radius_meters;
                $target->Z_Limit = $zone->radius_meters ?? $zone->Z_Limit;
                $target->approval_status = 'approved';
                $target->Z_state = 'active';
                $target->activated_at = now();
                $target->updated_at = now();
                $target->save();

                $zone->approval_status = 'approved';
                $zone->Z_state = 'replaced';
                $zone->activated_at = null;
                $zone->updated_at = now();
                $zone->save();

                return response()->json([
                    'status' => 'success',
                    'message' => 'تمت الموافقة واستبدال هندسة المنطقة الآمنة',
                    'data' => $this->serializeZone($target->fresh()),
                    'proposal' => $this->serializeZone($zone->fresh()),
                ]);
            }

            $zone->approval_status = 'approved';
            $zone->Z_state = 'active';
            $zone->activated_at = now();
            $msg = 'تمت الموافقة على المنطقة وتفعيلها';
        } else {
            // Reject keeps any replaced active zone untouched.
            $zone->approval_status = 'rejected';
            $zone->Z_state = 'rejected';
            $zone->activated_at = null;
            $msg = 'تم رفض مقترح المنطقة';
        }
        $zone->updated_at = now();
        $zone->save();

        return response()->json([
            'status' => 'success',
            'message' => $msg,
            'data' => $this->serializeZone($zone->fresh()),
        ]);
    }

    private function isSharingEnabled(int $elderlyId): bool
    {
        if (! Schema::hasColumn('elderly', 'location_sharing_enabled')) {
            return false;
        }

        $row = Elderly::query()->where('Eldery_ID', $elderlyId)->first();

        return $row ? (bool) $row->location_sharing_enabled : false;
    }

    private function freshnessLabel(?string $updateTime): string
    {
        if ($updateTime === null || $updateTime === '') {
            return 'unknown';
        }
        try {
            $dt = Carbon::parse($updateTime);
            $mins = Carbon::now()->diffInMinutes($dt, true);
            if ($mins <= 2) {
                return 'fresh';
            }
            if ($mins <= 30) {
                return 'recent';
            }
            if ($mins <= 24 * 60) {
                return 'stale';
            }

            return 'old';
        } catch (\Throwable $e) {
            return 'unknown';
        }
    }

    private function serializeLocation(LocationTracking $location): array
    {
        $data = $location->toArray();
        $data['latitude'] = $location->L_Latitude;
        $data['Longitude'] = $location->L_Longitude;
        $data['longitude'] = $location->L_Longitude;
        $data['accuracy_meters'] = $location->L_AccuracyMeters ?? null;
        $data['L_AccuracyMeters'] = $location->L_AccuracyMeters ?? null;
        $data['updated_at'] = $location->L_UpdateTime;
        $data['freshness'] = $this->freshnessLabel($location->L_UpdateTime);

        return $data;
    }

    private function serializeZone(SafeZone $zone): array
    {
        $data = $zone->toArray();
        $data['name'] = $zone->Z_Name;
        $data['radius_meters'] = $zone->radius_meters ?? $zone->Z_Limit;
        $data['latitude'] = $zone->center_lat;
        $data['longitude'] = $zone->center_lng;
        $data['replaces_zone_id'] = $zone->replaces_zone_id !== null
            ? (int) $zone->replaces_zone_id
            : null;
        $data['is_proposal'] = $zone->replaces_zone_id !== null
            || $zone->approval_status === 'pending';
        $data['is_active'] = in_array((string) $zone->Z_state, ['active', 'Active', 'نشط'], true)
            && $zone->approval_status === 'approved';

        return $data;
    }

    /**
     * @return array{name:string,lat:float,lng:float,radius:int}|\Illuminate\Http\JsonResponse
     */
    private function parseZoneInput(Request $request, bool $allowPartial = false, ?SafeZone $existing = null)
    {
        $name = $request->input('Z_Name', $request->input('name', $existing?->Z_Name));
        $lat = $request->input(
            'center_lat',
            $request->input('latitude', $request->input('L_Latitude', $existing?->center_lat))
        );
        $lng = $request->input(
            'center_lng',
            $request->input('longitude', $request->input('L_Longitude', $request->input('Longitude', $existing?->center_lng)))
        );
        $radius = $request->input(
            'radius_meters',
            $request->input('radius', $request->input('Z_Limit', $existing?->radius_meters ?? $existing?->Z_Limit))
        );

        if (! $allowPartial || $existing === null) {
            if ($name === null || trim((string) $name) === '') {
                return response()->json(['status' => 'error', 'message' => 'اسم المنطقة مطلوب'], 422);
            }
            if ($lat === null || $lng === null || $radius === null) {
                return response()->json(['status' => 'error', 'message' => 'مركز ونصف قطر المنطقة مطلوبان'], 422);
            }
        }

        $lat = (float) $lat;
        $lng = (float) $lng;
        $radius = (int) $radius;

        if (! is_finite($lat) || ! is_finite($lng) || abs($lat) > 90 || abs($lng) > 180) {
            return response()->json(['status' => 'error', 'message' => 'إحداثيات المركز غير صالحة'], 422);
        }
        if ($radius < 20 || $radius > 50000) {
            return response()->json(['status' => 'error', 'message' => 'نصف القطر يجب أن يكون بين 20 و 50000 متر'], 422);
        }

        return [
            'name' => trim((string) $name),
            'lat' => $lat,
            'lng' => $lng,
            'radius' => $radius,
        ];
    }
}
