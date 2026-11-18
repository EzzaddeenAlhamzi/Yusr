<?php

namespace App\Support;

use App\Models\Caregiver;
use App\Models\Elderly;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * P1.2 ownership / role authorization helpers for REST + legacy controllers.
 */
class YusrAccess
{
    public static function unauthenticated(?string $message = null): JsonResponse
    {
        return response()->json([
            'status' => 'error',
            'error_type' => 'unauthenticated',
            'message' => $message ?? 'يجب تسجيل الدخول للوصول إلى هذا المورد',
        ], 401);
    }

    public static function forbidden(?string $message = null): JsonResponse
    {
        return response()->json([
            'status' => 'error',
            'error_type' => 'forbidden',
            'message' => $message ?? 'ليس لديك صلاحية للوصول إلى هذا المورد',
        ], 403);
    }

    public static function notFound(?string $message = null): JsonResponse
    {
        return response()->json([
            'status' => 'error',
            'error_type' => 'not_found',
            'message' => $message ?? 'المورد غير موجود',
        ], 404);
    }

    public static function actor(Request $request): Caregiver|Elderly|null
    {
        $user = $request->user();
        if ($user instanceof Caregiver || $user instanceof Elderly) {
            return $user;
        }

        return null;
    }

    public static function requireActor(Request $request): Caregiver|Elderly|JsonResponse
    {
        $actor = self::actor($request);
        if ($actor === null) {
            return self::unauthenticated();
        }

        return $actor;
    }

    /**
     * @return list<int>
     */
    public static function accessibleElderlyIds(Caregiver|Elderly $actor): array
    {
        if ($actor instanceof Elderly) {
            return [(int) $actor->Eldery_ID];
        }

        $linked = (int) ($actor->Eldery_ID ?? 0);

        return $linked > 0 ? [$linked] : [];
    }

    public static function canAccessElderly(Caregiver|Elderly $actor, int|string|null $elderlyId): bool
    {
        if ($elderlyId === null || $elderlyId === '') {
            return false;
        }

        $elderlyId = (int) $elderlyId;
        if ($elderlyId <= 0) {
            return false;
        }

        return in_array($elderlyId, self::accessibleElderlyIds($actor), true);
    }

    public static function canViewCaregiver(Caregiver|Elderly $actor, int|string|null $caregiverId): bool
    {
        if ($caregiverId === null || $caregiverId === '') {
            return false;
        }

        $caregiverId = (int) $caregiverId;
        if ($actor instanceof Caregiver) {
            return (int) $actor->Caregivers_ID === $caregiverId;
        }

        return Caregiver::query()
            ->where('Caregivers_ID', $caregiverId)
            ->where('Eldery_ID', $actor->Eldery_ID)
            ->exists();
    }

    public static function canModifyCaregiver(Caregiver|Elderly $actor, int|string|null $caregiverId): bool
    {
        if (! ($actor instanceof Caregiver)) {
            return false;
        }

        return (int) $actor->Caregivers_ID === (int) $caregiverId;
    }

    public static function canModifyElderly(Caregiver|Elderly $actor, int|string|null $elderlyId): bool
    {
        return self::canAccessElderly($actor, $elderlyId);
    }

    public static function resolveElderlyId(Request $request, ...$fallbacks): ?int
    {
        $candidates = [
            $request->query('elderly_id'),
            $request->query('Elderly_ID'),
            $request->query('Eldery_ID'),
            $request->input('elderly_id'),
            $request->input('Elderly_ID'),
            $request->input('Eldery_ID'),
            ...$fallbacks,
        ];

        foreach ($candidates as $value) {
            if ($value === null || $value === '') {
                continue;
            }
            $id = (int) $value;
            if ($id > 0) {
                return $id;
            }
        }

        return null;
    }

    /**
     * Gate elderly-scoped reads/writes. Returns authorized elderly id, or error response.
     * When $required is false and no id is provided, returns null (caller should scope lists).
     */
    public static function gateElderly(
        Request $request,
        ?int $elderlyId = null,
        bool $required = true
    ): int|JsonResponse|null {
        $actor = self::requireActor($request);
        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $elderlyId = $elderlyId ?? self::resolveElderlyId($request);

        if ($elderlyId === null) {
            if ($required) {
                // Prefer defaulting to the actor's own/linked elderly when unique.
                $ids = self::accessibleElderlyIds($actor);
                if (count($ids) === 1) {
                    return $ids[0];
                }

                return self::forbidden('معرف كبير السن مطلوب أو غير مصرح');
            }

            return null;
        }

        if (! self::canAccessElderly($actor, $elderlyId)) {
            return self::forbidden('غير مصرح بالوصول إلى بيانات هذا الكبير في السن');
        }

        return $elderlyId;
    }

    /**
     * Scope a query builder callback to accessible elderly ids (never unscoped dump).
     *
     * @param  callable(\Illuminate\Database\Eloquent\Builder, list<int>): void  $apply
     */
    public static function withElderlyScope(Request $request, callable $apply): JsonResponse|true
    {
        $actor = self::requireActor($request);
        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $requested = self::resolveElderlyId($request);
        $allowed = self::accessibleElderlyIds($actor);

        if ($requested !== null) {
            if (! in_array($requested, $allowed, true)) {
                return self::forbidden('غير مصرح بالوصول إلى بيانات هذا الكبير في السن');
            }
            $apply(null, [$requested]);

            return true;
        }

        if ($allowed === []) {
            $apply(null, []);

            return true;
        }

        $apply(null, $allowed);

        return true;
    }
}
