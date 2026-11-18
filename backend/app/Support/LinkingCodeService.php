<?php

namespace App\Support;

use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\ElderlyLinkingCode;
use App\Models\LinkingCodeAttempt;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Secure temporary linking codes: 6-digit, hashed, 10min, single-use, rate-limited.
 * Never logs plaintext codes.
 */
class LinkingCodeService
{
    public static function hashCode(string $code): string
    {
        $normalized = self::normalizeCode($code);

        return hash_hmac('sha256', $normalized, (string) config('app.key'));
    }

    public static function normalizeCode(string $code): string
    {
        $digits = preg_replace('/\D+/', '', $code) ?? '';
        $len = (int) config('yusr_linking.code_length', 6);

        return str_pad(substr($digits, 0, $len), $len, '0', STR_PAD_LEFT);
    }

    public static function isValidCodeFormat(string $code): bool
    {
        $len = (int) config('yusr_linking.code_length', 6);
        $normalized = self::normalizeCode($code);

        return strlen($normalized) === $len && ctype_digit($normalized);
    }

    /**
     * Generate a new code for the authenticated elderly (self only).
     * Invalidates any prior active codes for that elderly.
     *
     * @return array{code: string, expires_at: string, expires_in_seconds: int}|JsonResponse
     */
    public static function generateForElderly(Elderly $elderly): array|JsonResponse
    {
        $ttl = (int) config('yusr_linking.ttl_minutes', 10);
        $len = (int) config('yusr_linking.code_length', 6);

        // Cryptographically secure 6-digit numeric (leading zeros preserved as string).
        $max = (10 ** $len) - 1;
        $n = random_int(0, $max);
        $plain = str_pad((string) $n, $len, '0', STR_PAD_LEFT);
        $hash = self::hashCode($plain);
        $expiresAt = now()->addMinutes($ttl);

        DB::transaction(function () use ($elderly, $hash, $expiresAt) {
            // Invalidate superseded active codes (mark consumed).
            ElderlyLinkingCode::query()
                ->where('Eldery_ID', $elderly->Eldery_ID)
                ->whereNull('consumed_at')
                ->where('expires_at', '>', now())
                ->update(['consumed_at' => now()]);

            ElderlyLinkingCode::query()->create([
                'Eldery_ID' => $elderly->Eldery_ID,
                'code_hash' => $hash,
                'expires_at' => $expiresAt,
                'consumed_at' => null,
                'created_at' => now(),
            ]);
        });

        // Intentional: plaintext returned once to the authenticated elderly only.
        // Never log $plain.
        Log::info('elderly_linking_code_generated', [
            'Eldery_ID' => $elderly->Eldery_ID,
            'expires_at' => $expiresAt->toIso8601String(),
        ]);

        return [
            'code' => $plain,
            'expires_at' => $expiresAt->toIso8601String(),
            'expires_in_seconds' => $ttl * 60,
        ];
    }

    /**
     * Rate-limit check. Returns lockout JsonResponse or null if allowed.
     */
    public static function rateLimitResponse(Caregiver $caregiver, ?string $ip): ?JsonResponse
    {
        $window = (int) config('yusr_linking.attempt_window_minutes', 10);
        $maxCg = (int) config('yusr_linking.max_failed_attempts', 5);
        $maxIp = (int) config('yusr_linking.max_failed_attempts_per_ip', 20);
        $since = now()->subMinutes($window);

        $cgFails = LinkingCodeAttempt::query()
            ->where('Caregivers_ID', $caregiver->Caregivers_ID)
            ->where('attempted_at', '>=', $since)
            ->count();

        if ($cgFails >= $maxCg) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'rate_limited',
                'message' => 'تم تجاوز عدد محاولات الربط المسموح بها. حاول لاحقاً.',
            ], 429);
        }

        if ($ip !== null && $ip !== '') {
            $ipFails = LinkingCodeAttempt::query()
                ->where('ip_address', $ip)
                ->where('attempted_at', '>=', $since)
                ->count();
            if ($ipFails >= $maxIp) {
                return response()->json([
                    'status' => 'error',
                    'error_type' => 'rate_limited',
                    'message' => 'تم تجاوز عدد محاولات الربط المسموح بها. حاول لاحقاً.',
                ], 429);
            }
        }

        return null;
    }

    public static function recordFailedAttempt(Caregiver $caregiver, ?string $ip): void
    {
        LinkingCodeAttempt::query()->create([
            'Caregivers_ID' => $caregiver->Caregivers_ID,
            'ip_address' => $ip,
            'attempted_at' => now(),
        ]);
    }

    /**
     * Consume a linking code atomically and attach caregiver → elderly.
     * Safe generic errors (no existence oracle for a specific elderly).
     *
     * @return array{caregiver: Caregiver, elderly: Elderly}|JsonResponse
     */
    public static function consumeAndLink(Caregiver $caregiver, string $code, ?string $ip): array|JsonResponse
    {
        if ($lock = self::rateLimitResponse($caregiver, $ip)) {
            return $lock;
        }

        if (! self::isValidCodeFormat($code)) {
            self::recordFailedAttempt($caregiver, $ip);

            return response()->json([
                'status' => 'error',
                'error_type' => 'validation_error',
                'message' => 'رمز الربط غير صالح أو منتهي الصلاحية',
            ], 200);
        }

        $hash = self::hashCode($code);

        try {
            $result = DB::transaction(function () use ($caregiver, $hash) {
                /** @var ElderlyLinkingCode|null $row */
                $row = ElderlyLinkingCode::query()
                    ->where('code_hash', $hash)
                    ->whereNull('consumed_at')
                    ->where('expires_at', '>', now())
                    ->lockForUpdate()
                    ->first();

                if ($row === null) {
                    return null;
                }

                // Atomic single-use: conditional update.
                $updated = ElderlyLinkingCode::query()
                    ->where('id', $row->id)
                    ->whereNull('consumed_at')
                    ->where('expires_at', '>', now())
                    ->update(['consumed_at' => now()]);

                if ($updated !== 1) {
                    return null;
                }

                $elderly = Elderly::query()->find($row->Eldery_ID);
                if ($elderly === null) {
                    return null;
                }

                // Already linked to this elderly → idempotent success.
                if ((int) ($caregiver->Eldery_ID ?? 0) === (int) $elderly->Eldery_ID) {
                    return ['caregiver' => $caregiver->fresh(), 'elderly' => $elderly];
                }

                // Prevent duplicate active relationship from this caregiver to a different elderly
                // by reassigning (one Eldery_ID column). Ownership: self only.
                $caregiver->update(['Eldery_ID' => $elderly->Eldery_ID]);

                return [
                    'caregiver' => $caregiver->fresh(),
                    'elderly' => $elderly,
                ];
            });
        } catch (\Throwable $e) {
            Log::warning('linking_code_consume_failed', [
                'Caregivers_ID' => $caregiver->Caregivers_ID,
                'error' => $e->getMessage(),
            ]);
            self::recordFailedAttempt($caregiver, $ip);

            return response()->json([
                'status' => 'error',
                'error_type' => 'validation_error',
                'message' => 'رمز الربط غير صالح أو منتهي الصلاحية',
            ], 200);
        }

        if ($result === null) {
            self::recordFailedAttempt($caregiver, $ip);

            return response()->json([
                'status' => 'error',
                'error_type' => 'validation_error',
                'message' => 'رمز الربط غير صالح أو منتهي الصلاحية',
            ], 200);
        }

        return $result;
    }
}
