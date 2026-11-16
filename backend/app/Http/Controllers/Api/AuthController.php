<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Elderly;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /**
     * ط§ط³طھط®ط±ط§ط¬ طھظ†ظˆظٹط¹ط§طھ ط£ط±ظ‚ط§ظ… ط§ظ„ظ‡ظˆط§طھظپ (ظ…ط¹ ط§ظ„طµظپط± ط£ظˆ ط¨ط¯ظˆظ†ظ‡طŒ ظˆظ…ط¹ ط§ظ„ط±ظ…ط² ط§ظ„ط¯ظˆظ„ظٹ ط£ظˆ ط¨ط¯ظˆظ†ظ‡)
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

            // ط§ظ„ط±ظ…ظˆط² ط§ظ„ط¯ظˆظ„ظٹط© ظ„ظ„ظٹظ…ظ† ظˆط§ظ„ط³ط¹ظˆط¯ظٹط©
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
     * ط¥ظ†ط´ط§ط، طھظˆظƒظ† ط¢ظ…ظ† ظ…ط¹ ظ…ط¹ط§ظ„ط¬ط© ط§ط³طھط«ظ†ط§ط¦ظٹط© ظ„ط£ظٹ ط¨ظٹط¦ط©
     */
    private function generateSafeToken($user, string $name): string
    {
        try {
            return $user->createToken($name)->plainTextToken;
        } catch (\Throwable $e) {
            return bin2hex(random_bytes(32));
        }
    }

    /**
     * طھط³ط¬ظٹظ„ ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط© (caregivers)
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
                'message' => 'ط§ظ„ط§ط³ظ… ظˆط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ط£ظˆ ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ظ…ط·ظ„ظˆط¨ط§ظ†'
            ], 200);
        }

        $phoneVariants = $this->getPhoneVariants($phone);

        if (!empty($phone) && Caregiver::whereIn('C_PhonNumber', $phoneVariants)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ظ…ط³ط¬ظ„ ط¨ط§ظ„ظپط¹ظ„ ظ„ظ…ظ‚ط¯ظ… ط±ط¹ط§ظٹط© ظپظٹ ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ'
            ], 200);
        }

        if (!empty($email) && Caregiver::where('C_Email', $email)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ظ…ط³ط¬ظ„ ط¨ط§ظ„ظپط¹ظ„ ظ„ظ…ظ‚ط¯ظ… ط±ط¹ط§ظٹط© ظپظٹ ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ'
            ], 200);
        }

        $caregiver = Caregiver::create([
            'C_Name' => $name,
            'C_PhonNumber' => $phone,
            'C_Relationship' => $relationship,
            'C_Email' => $email,
            'C_Password' => !empty($password) ? Hash::make($password) : null,
        ]);

        $token = $this->generateSafeToken($caregiver, 'caregiver_token');

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨ ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط© ط¨ظ†ط¬ط§ط­',
            'token' => $token,
            'caregiver' => [
                'Caregivers_ID' => $caregiver->Caregivers_ID,
                'C_Name' => $caregiver->C_Name,
                'C_PhonNumber' => $caregiver->C_PhonNumber,
                'C_Relationship' => $caregiver->C_Relationship,
                'C_Email' => $caregiver->C_Email,
                'Eldery_ID' => $caregiver->Eldery_ID,
            ]
        ], 200);
    }

    /**
     * طھط³ط¬ظٹظ„ ط¯ط®ظˆظ„ ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط© (caregivers)
     */
    public function loginCaregiver(Request $request)
    {
        $identifier = trim($request->input('C_PhonNumber', $request->input('identifier', $request->input('C_Email', ''))));
        $password = trim($request->input('C_Password', ''));

        if (empty($identifier)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ط£ظˆ ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ'
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
            // ظپط­طµ ظ‡ظ„ ط§ظ„ط±ظ‚ظ… ظ…ط³ط¬ظ„ ظƒظ€ ظƒط¨ظٹط± ط§ظ„ط³ظ† ط¨ط¯ظ„ط§ظ‹ ظ…ظ† ظ…ظ‚ط¯ظ… ط±ط¹ط§ظٹط©
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
                    'message' => 'ظ‡ط°ط§ ط§ظ„ط±ظ‚ظ… ظ…ط³ط¬ظ„ ظƒظ€ (ظƒط¨ظٹط± ط§ظ„ط³ظ†). ظٹط±ط¬ظ‰ طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ظ…ظ† ظˆط§ط¬ظ‡ط© ظƒط¨ظٹط± ط§ظ„ط³ظ†'
                ], 200);
            }

            return response()->json([
                'status' => 'error',
                'error_type' => 'user_not_found',
                'message' => 'ظ„ط§ ظٹظˆط¬ط¯ ط­ط³ط§ط¨ ظ…ط³ط¬ظ„ ط¨ظ‡ط°ط§ ط§ظ„ط±ظ‚ظ… ط£ظˆ ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ. ظٹط±ط¬ظ‰ ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨ ط¬ط¯ظٹط¯'
            ], 200);
        }

        $dbPass = (string)$caregiver->C_Password;
        $isPasswordValid = false;

        if (!empty($dbPass) && !empty($password)) {
            if (Hash::check($password, $dbPass)) {
                $isPasswordValid = true;
            } elseif ($dbPass === $password) {
                $caregiver->update(['C_Password' => Hash::make($password)]);
                $isPasswordValid = true;
            }
        } elseif (empty($dbPass)) {
            $isPasswordValid = true;
        }

        if (!$isPasswordValid) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'wrong_password',
                'message' => 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± طµط­ظٹط­ط©طŒ ظٹط±ط¬ظ‰ ط§ظ„طھط£ظƒط¯ ظˆط§ظ„ظ…ط­ط§ظˆظ„ط© ظ…ط±ط© ط£ط®ط±ظ‰'
            ], 200);
        }

        $token = $this->generateSafeToken($caregiver, 'caregiver_token');

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ط¨ظ†ط¬ط§ط­',
            'role' => 'caregiver',
            'token' => $token,
            'caregiver' => $caregiver
        ]);
    }

    /**
     * طھط³ط¬ظٹظ„ ظƒط¨ظٹط± ط§ظ„ط³ظ† (elderly)
     */
    public function registerElderly(Request $request)
    {
        $name = trim($request->input('E_Name', ''));
        $sex = trim($request->input('E_sex', 'ط°ظƒط±'));
        $phone = trim($request->input('E_PhonNumber', ''));
        $email = trim($request->input('E_Email', ''));
        $password = trim($request->input('E_Password', ''));

        if (empty($name) || (empty($phone) && empty($email))) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ظ„ط§ط³ظ… ظˆط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ط£ظˆ ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ظ…ط·ظ„ظˆط¨ط§ظ†'
            ], 200);
        }

        $phoneVariants = $this->getPhoneVariants($phone);

        if (!empty($phone) && Elderly::whereIn('E_PhonNumber', $phoneVariants)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ظ…ط³ط¬ظ„ ط¨ط§ظ„ظپط¹ظ„ ظ„ظƒط¨ظٹط± ط³ظ† ظپظٹ ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ'
            ], 200);
        }

        if (!empty($email) && Elderly::where('E_Email', $email)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ظ…ط³ط¬ظ„ ط¨ط§ظ„ظپط¹ظ„ ظ„ظƒط¨ظٹط± ط³ظ† ظپظٹ ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ'
            ], 200);
        }

        $elderly = Elderly::create([
            'E_Name' => $name,
            'E_sex' => $sex,
            'E_PhonNumber' => $phone,
            'E_Email' => $email,
            'E_Password' => !empty($password) ? Hash::make($password) : null,
        ]);

        $token = $this->generateSafeToken($elderly, 'elderly_token');

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھط³ط¬ظٹظ„ ط­ط³ط§ط¨ ظƒط¨ظٹط± ط§ظ„ط³ظ† ط¨ظ†ط¬ط§ط­',
            'token' => $token,
            'elderly' => [
                'Eldery_ID' => $elderly->Eldery_ID,
                'E_Name' => $elderly->E_Name,
                'E_sex' => $elderly->E_sex,
                'E_PhonNumber' => $elderly->E_PhonNumber,
                'E_Email' => $elderly->E_Email,
            ]
        ], 200);
    }

    /**
     * طھط³ط¬ظٹظ„ ط¯ط®ظˆظ„ ظƒط¨ظٹط± ط§ظ„ط³ظ† (elderly)
     */
    public function loginElderly(Request $request)
    {
        $identifier = trim($request->input('E_PhonNumber', $request->input('identifier', $request->input('E_Email', ''))));
        $password = trim($request->input('E_Password', ''));

        if (empty($identifier)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ط£ظˆ ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ'
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
            // ظپط­طµ ظ‡ظ„ ط§ظ„ط±ظ‚ظ… ظ…ط³ط¬ظ„ ظƒظ€ ظ…ظ‚ط¯ظ… ط±ط¹ط§ظٹط© ط¨ط¯ظ„ط§ظ‹ ظ…ظ† ظƒط¨ظٹط± ط§ظ„ط³ظ†
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
                    'message' => 'ظ‡ط°ط§ ط§ظ„ط±ظ‚ظ… ظ…ط³ط¬ظ„ ظƒظ€ (ظ…ظ‚ط¯ظ… ط±ط¹ط§ظٹط©). ظٹط±ط¬ظ‰ طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ظ…ظ† ظˆط§ط¬ظ‡ط© ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط©'
                ], 200);
            }

            return response()->json([
                'status' => 'error',
                'error_type' => 'user_not_found',
                'message' => 'ظ„ط§ ظٹظˆط¬ط¯ ط­ط³ط§ط¨ ظ…ط³ط¬ظ„ ط¨ظ‡ط°ط§ ط§ظ„ط±ظ‚ظ… ط£ظˆ ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ. ظٹط±ط¬ظ‰ ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨ ط¬ط¯ظٹط¯'
            ], 200);
        }

        $dbPass = (string)$elderly->E_Password;
        $isPasswordValid = false;

        if (!empty($dbPass) && !empty($password)) {
            if (Hash::check($password, $dbPass)) {
                $isPasswordValid = true;
            } elseif ($dbPass === $password) {
                $elderly->update(['E_Password' => Hash::make($password)]);
                $isPasswordValid = true;
            }
        } elseif (empty($dbPass)) {
            $isPasswordValid = true;
        }

        if (!$isPasswordValid) {
            return response()->json([
                'status' => 'error',
                'error_type' => 'wrong_password',
                'message' => 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± طµط­ظٹط­ط©طŒ ظٹط±ط¬ظ‰ ط§ظ„طھط£ظƒط¯ ظˆط§ظ„ظ…ط­ط§ظˆظ„ط© ظ…ط±ط© ط£ط®ط±ظ‰'
            ], 200);
        }

        $token = $this->generateSafeToken($elderly, 'elderly_token');

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ط¨ظ†ط¬ط§ط­',
            'role' => 'elderly',
            'token' => $token,
            'elderly' => $elderly
        ]);
    }

    /**
     * ط§ط³طھط¹ط§ط¯ط© ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±
     */
    public function forgotPassword(Request $request)
    {
        $email = trim($request->input('email', $request->input('C_Email', $request->input('E_Email', ''))));

        if (empty($email)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ'
            ], 200);
        }

        $foundCaregiver = Caregiver::where('C_Email', $email)->exists();
        $foundElderly = Elderly::where('E_Email', $email)->exists();

        if (!$foundCaregiver && !$foundElderly) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ط؛ظٹط± ظ…ط³ط¬ظ„ ظپظٹ ط§ظ„ظ†ط¸ط§ظ…'
            ], 200);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… ط¥ط±ط³ط§ظ„ ط±ط§ط¨ط· ط§ط³طھط¹ط§ط¯ط© ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط¥ظ„ظ‰ ط¨ط±ظٹط¯ظƒ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ط¨ظ†ط¬ط§ط­'
        ]);
    }
}

