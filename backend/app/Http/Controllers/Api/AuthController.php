<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Elderly;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /**
     * استخراج تنويعات أرقام الهاتف (مع الصفر أو بدونه، ومع الرمز الدولي أو بدونه)
     */
    private function getPhoneVariants(string $phone): array
    {
        $clean = trim($phone);
        if (empty($clean)) {
            return [];
        }
        $digits = preg_replace('/[^0-9]/', '', $clean);
        $variants = array_filter([$clean, $digits]);

        if (!empty($digits)) {
            if (str_starts_with($digits, '0')) {
                $variants[] = substr($digits, 1);
            } else {
                $variants[] = '0' . $digits;
            }

            // الرموز الدولية لليمن والسعودية
            foreach (['967', '966'] as $cc) {
                if (str_starts_with($digits, $cc)) {
                    $local = substr($digits, strlen($cc));
                    $variants[] = $local;
                    $variants[] = '0' . $local;
                }
            }
        }

        return array_values(array_unique(array_filter($variants)));
    }

    /**
     * إنشاء توكن Sanctum فقط عند النجاح — fail-closed (لا hex يتيم).
     */
    private function generateSafeToken($user, string $name): ?string
    {
        try {
            $plain = $user->createToken($name)->plainTextToken;
            if (empty($plain)) {
                return null;
            }

            return $plain;
        } catch (\Throwable $e) {
            return null;
        }
    }

    private function tokenFailureResponse(): JsonResponse
    {
        return response()->json([
            'status' => 'error',
            'error_type' => 'token_issue_failed',
            'message' => 'تعذر إصدار رمز الجلسة. يرجى المحاولة لاحقاً',
        ], 503);
    }

    /**
     * التحقق من كلمة المرور المخزّنة.
     * - فارغة في الطلب أو في قاعدة البيانات → فشل
     * - bcrypt/argon صحيح → نجاح
     * - تطابق نص صريح قديم → رفض مع طلب إعادة تعيين (بدون ترقية صامتة)
     */
    private function verifyStoredPassword(string $plain, ?string $stored): array
    {
        $stored = (string) ($stored ?? '');
        $plain = trim($plain);

        if ($plain === '' || $stored === '') {
            return [
                'ok' => false,
                'error_type' => 'wrong_password',
                'message' => 'كلمة المرور غير صحيحة، يرجى التأكد والمحاولة مرة أخرى',
            ];
        }

        if ($this->looksLikePasswordHash($stored)) {
            if (Hash::check($plain, $stored)) {
                return ['ok' => true];
            }

            return [
                'ok' => false,
                'error_type' => 'wrong_password',
                'message' => 'كلمة المرور غير صحيحة، يرجى التأكد والمحاولة مرة أخرى',
            ];
        }

        // Plaintext / legacy non-hash path — reject; do not silently rehash on login.
        return [
            'ok' => false,
            'error_type' => 'password_reset_required',
            'message' => 'يجب إعادة تعيين كلمة المرور قبل تسجيل الدخول. الحساب يستخدم تخزيناً غير آمن',
        ];
    }

    private function looksLikePasswordHash(string $value): bool
    {
        // bcrypt ($2y$ / $2a$ / $2b$), argon2i/argon2id, or Laravel Hash::info
        if (preg_match('/^\$2[ayb]\$\d{2}\$.{53}$/', $value) === 1) {
            return true;
        }
        if (str_starts_with($value, '$argon2')) {
            return true;
        }

        try {
            $info = Hash::info($value);

            return !empty($info['algo']);
        } catch (\Throwable $e) {
            return false;
        }
    }

    /**
     * تسجيل مقدم الرعاية (caregivers)
     */
    public function registerCaregiver(Request $request)
    {
        $name = trim($request->input('C_Name', ''));
        $phone = trim($request->input('C_PhonNumber', ''));
        $relationship = trim($request->input('C_Relationship', ''));
        $email = trim($request->input('C_Email', ''));
        $password = trim($request->input('C_Password', ''));

        if (empty($name) || (empty($phone) && empty($email))) {
            return response()->json([
                'status' => 'error',
                'message' => 'الاسم ورقم الهاتف أو البريد الإلكتروني مطلوبان',
            ], 200);
        }

        if ($password === '') {
            return response()->json([
                'status' => 'error',
                'error_type' => 'password_required',
                'message' => 'كلمة المرور مطلوبة لإنشاء الحساب',
            ], 200);
        }

        $phoneVariants = $this->getPhoneVariants($phone);

        if (!empty($phone) && Caregiver::whereIn('C_PhonNumber', $phoneVariants)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'رقم الهاتف مسجل بالفعل لمقدم رعاية في قاعدة البيانات',
            ], 200);
        }

        if (!empty($email) && Caregiver::where('C_Email', $email)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'البريد الإلكتروني مسجل بالفعل لمقدم رعاية في قاعدة البيانات',
            ], 200);
        }

        $caregiver = Caregiver::create([
            'C_Name' => $name,
            'C_PhonNumber' => $phone,
            'C_Relationship' => $relationship,
            'C_Email' => $email,
            'C_Password' => Hash::make($password),
        ]);

        $token = $this->generateSafeToken($caregiver, 'caregiver_token');
        if ($token === null) {
            $caregiver->delete();

            return $this->tokenFailureResponse();
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم إنشاء حساب مقدم الرعاية بنجاح',
            'token' => $token,
            'caregiver' => [
                'Caregivers_ID' => $caregiver->Caregivers_ID,
                'C_Name' => $caregiver->C_Name,
                'C_PhonNumber' => $caregiver->C_PhonNumber,
                'C_Relationship' => $caregiver->C_Relationship,
                'C_Email' => $caregiver->C_Email,
                'Eldery_ID' => $caregiver->Eldery_ID,
            ],
        ], 200);
    }

    /**
     * تسجيل دخول مقدم الرعاية (caregivers)
     */
    public function loginCaregiver(Request $request)
    {
        $identifier = trim($request->input('C_PhonNumber', $request->input('identifier', $request->input('C_Email', ''))));
        $password = trim($request->input('C_Password', ''));

        if (empty($identifier)) {
            return response()->json([
                'status' => 'error',
                'message' => 'يرجى إدخال رقم الهاتف أو البريد الإلكتروني',
            ], 200);
        }

        $variants = $this->getPhoneVariants($identifier);

        $caregiver = Caregiver::where(function ($query) use ($identifier, $variants) {
            if (!empty($variants)) {
                $query->whereIn('C_PhonNumber', $variants);
            } else {
                $query->where('C_PhonNumber', $identifier);
            }
            if (!empty($identifier)) {
                $query->orWhere('C_Email', $identifier);
            }
        })->first();

        if (!$caregiver) {
            $elderlyExists = Elderly::where(function ($query) use ($identifier, $variants) {
                if (!empty($variants)) {
                    $query->whereIn('E_PhonNumber', $variants);
                } else {
                    $query->where('E_PhonNumber', $identifier);
                }
                if (!empty($identifier)) {
                    $query->orWhere('E_Email', $identifier);
                }
            })->exists();

            if ($elderlyExists) {
                return response()->json([
                    'status' => 'error',
                    'error_type' => 'role_mismatch',
                    'message' => 'هذا الرقم مسجل كـ (كبير السن). يرجى تسجيل الدخول من واجهة كبير السن',
                ], 200);
            }

            return response()->json([
                'status' => 'error',
                'error_type' => 'user_not_found',
                'message' => 'لا يوجد حساب مسجل بهذا الرقم أو البريد الإلكتروني. يرجى إنشاء حساب جديد',
            ], 200);
        }

        $check = $this->verifyStoredPassword($password, $caregiver->C_Password);
        if (!$check['ok']) {
            return response()->json([
                'status' => 'error',
                'error_type' => $check['error_type'],
                'message' => $check['message'],
            ], 200);
        }

        $token = $this->generateSafeToken($caregiver, 'caregiver_token');
        if ($token === null) {
            return $this->tokenFailureResponse();
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم تسجيل الدخول بنجاح',
            'role' => 'caregiver',
            'token' => $token,
            'caregiver' => [
                'Caregivers_ID' => $caregiver->Caregivers_ID,
                'C_Name' => $caregiver->C_Name,
                'C_PhonNumber' => $caregiver->C_PhonNumber,
                'C_Relationship' => $caregiver->C_Relationship,
                'C_Email' => $caregiver->C_Email,
                'Eldery_ID' => $caregiver->Eldery_ID,
            ],
        ], 200);
    }

    /**
     * تسجيل كبير السن (elderly)
     */
    public function registerElderly(Request $request)
    {
        $name = trim($request->input('E_Name', ''));
        $sex = trim($request->input('E_sex', 'ذكر'));
        $phone = trim($request->input('E_PhonNumber', ''));
        $email = trim($request->input('E_Email', ''));
        $password = trim($request->input('E_Password', ''));

        if (empty($name) || (empty($phone) && empty($email))) {
            return response()->json([
                'status' => 'error',
                'message' => 'الاسم ورقم الهاتف أو البريد الإلكتروني مطلوبان',
            ], 200);
        }

        if ($password === '') {
            return response()->json([
                'status' => 'error',
                'error_type' => 'password_required',
                'message' => 'كلمة المرور مطلوبة لإنشاء الحساب',
            ], 200);
        }

        $phoneVariants = $this->getPhoneVariants($phone);

        if (!empty($phone) && Elderly::whereIn('E_PhonNumber', $phoneVariants)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'رقم الهاتف مسجل بالفعل لكبير سن في قاعدة البيانات',
            ], 200);
        }

        if (!empty($email) && Elderly::where('E_Email', $email)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'البريد الإلكتروني مسجل بالفعل لكبير سن في قاعدة البيانات',
            ], 200);
        }

        $elderly = Elderly::create([
            'E_Name' => $name,
            'E_sex' => $sex,
            'E_PhonNumber' => $phone,
            'E_Email' => $email,
            'E_Password' => Hash::make($password),
        ]);

        $token = $this->generateSafeToken($elderly, 'elderly_token');
        if ($token === null) {
            $elderly->delete();

            return $this->tokenFailureResponse();
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم تسجيل حساب كبير السن بنجاح',
            'token' => $token,
            'elderly' => [
                'Eldery_ID' => $elderly->Eldery_ID,
                'E_Name' => $elderly->E_Name,
                'E_sex' => $elderly->E_sex,
                'E_PhonNumber' => $elderly->E_PhonNumber,
                'E_Email' => $elderly->E_Email,
            ],
        ], 200);
    }

    /**
     * تسجيل دخول كبير السن (elderly)
     */
    public function loginElderly(Request $request)
    {
        $identifier = trim($request->input('E_PhonNumber', $request->input('identifier', $request->input('E_Email', ''))));
        $password = trim($request->input('E_Password', ''));

        if (empty($identifier)) {
            return response()->json([
                'status' => 'error',
                'message' => 'يرجى إدخال رقم الهاتف أو البريد الإلكتروني',
            ], 200);
        }

        $variants = $this->getPhoneVariants($identifier);

        $elderly = Elderly::where(function ($query) use ($identifier, $variants) {
            if (!empty($variants)) {
                $query->whereIn('E_PhonNumber', $variants);
            } else {
                $query->where('E_PhonNumber', $identifier);
            }
            if (!empty($identifier)) {
                $query->orWhere('E_Email', $identifier);
            }
        })->first();

        if (!$elderly) {
            $caregiverExists = Caregiver::where(function ($query) use ($identifier, $variants) {
                if (!empty($variants)) {
                    $query->whereIn('C_PhonNumber', $variants);
                } else {
                    $query->where('C_PhonNumber', $identifier);
                }
                if (!empty($identifier)) {
                    $query->orWhere('C_Email', $identifier);
                }
            })->exists();

            if ($caregiverExists) {
                return response()->json([
                    'status' => 'error',
                    'error_type' => 'role_mismatch',
                    'message' => 'هذا الرقم مسجل كـ (مقدم رعاية). يرجى تسجيل الدخول من واجهة مقدم الرعاية',
                ], 200);
            }

            return response()->json([
                'status' => 'error',
                'error_type' => 'user_not_found',
                'message' => 'لا يوجد حساب مسجل بهذا الرقم أو البريد الإلكتروني. يرجى إنشاء حساب جديد',
            ], 200);
        }

        $check = $this->verifyStoredPassword($password, $elderly->E_Password);
        if (!$check['ok']) {
            return response()->json([
                'status' => 'error',
                'error_type' => $check['error_type'],
                'message' => $check['message'],
            ], 200);
        }

        $token = $this->generateSafeToken($elderly, 'elderly_token');
        if ($token === null) {
            return $this->tokenFailureResponse();
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم تسجيل الدخول بنجاح',
            'role' => 'elderly',
            'token' => $token,
            'elderly' => [
                'Eldery_ID' => $elderly->Eldery_ID,
                'E_Name' => $elderly->E_Name,
                'E_sex' => $elderly->E_sex,
                'E_PhonNumber' => $elderly->E_PhonNumber,
                'E_Email' => $elderly->E_Email,
            ],
        ], 200);
    }

    /**
     * استعادة كلمة المرور (stub — unchanged contract; real reset is out of P1.1)
     */
    public function forgotPassword(Request $request)
    {
        $email = trim($request->input('email', $request->input('C_Email', $request->input('E_Email', ''))));

        if (empty($email)) {
            return response()->json([
                'status' => 'error',
                'message' => 'يرجى إدخال البريد الإلكتروني',
            ], 200);
        }

        $foundCaregiver = Caregiver::where('C_Email', $email)->exists();
        $foundElderly = Elderly::where('E_Email', $email)->exists();

        if (!$foundCaregiver && !$foundElderly) {
            return response()->json([
                'status' => 'error',
                'message' => 'البريد الإلكتروني غير مسجل في النظام',
            ], 200);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني بنجاح',
        ]);
    }

    /**
     * P1.2: revoke current Sanctum token (logout).
     */
    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user && method_exists($user, 'currentAccessToken')) {
            $token = $user->currentAccessToken();
            if ($token) {
                $token->delete();
            }
        }
        // Also clear any remaining tokens for this model (fail-closed logout).
        if ($user && method_exists($user, 'tokens')) {
            $user->tokens()->delete();
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم تسجيل الخروج بنجاح',
        ]);
    }
}
