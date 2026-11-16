<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Elderly;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class ElderlyController extends Controller
{
    public function show($id)
    {
        $elderly = Elderly::find($id);

        if (!$elderly) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظƒط¨ظٹط± ط§ظ„ط³ظ† ط؛ظٹط± ظ…ظˆط¬ظˆط¯'
            ], 200);
        }

        return response()->json([
            'status' => 'success',
            'data' => $elderly
        ]);
    }

    public function update(Request $request, $id = null)
    {
        $elderlyId = $id ?? $request->input('Eldery_ID');
        $elderly = Elderly::find($elderlyId);

        if (!$elderly) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظƒط¨ظٹط± ط§ظ„ط³ظ† ط؛ظٹط± ظ…ظˆط¬ظˆط¯'
            ], 200);
        }

        $fields = [];
        if ($request->has('E_Name')) $fields['E_Name'] = $request->input('E_Name');
        if ($request->has('E_sex')) $fields['E_sex'] = $request->input('E_sex');
        if ($request->has('E_PhonNumber')) $fields['E_PhonNumber'] = $request->input('E_PhonNumber');
        if ($request->has('E_Email')) $fields['E_Email'] = $request->input('E_Email');
        if ($request->has('E_Password') && !empty($request->input('E_Password'))) {
            $fields['E_Password'] = Hash::make($request->input('E_Password'));
        }

        $elderly->update($fields);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھط­ط¯ظٹط« ط¨ظٹط§ظ†ط§طھ ظƒط¨ظٹط± ط§ظ„ط³ظ† ط¨ظ†ط¬ط§ط­',
            'data' => $elderly
        ]);
    }

    public function linkCaregiver(Request $request)
    {
        $caregiverId = $request->input('Caregivers_ID');
        $elderlyId = $request->input('Eldery_ID');

        if (!$caregiverId || !$elderlyId) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظ…ط¹ط±ظپ ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط© ظˆظ…ط¹ط±ظپ ظƒط¨ظٹط± ط§ظ„ط³ظ† ظ…ط·ظ„ظˆط¨ط§ظ†'
            ], 200);
        }

        $caregiver = Caregiver::find($caregiverId);
        $elderly = Elderly::find($elderlyId);

        if (!$caregiver || !$elderly) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط© ط£ظˆ ظƒط¨ظٹط± ط§ظ„ط³ظ† ط؛ظٹط± ظ…ظˆط¬ظˆط¯ ظپظٹ ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ'
            ], 200);
        }

        $caregiver->update(['Eldery_ID' => $elderlyId]);

        return response()->json([
            'status' => 'success',
            'message' => "طھظ… ط±ط¨ط· ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط© ({$caregiver->C_Name}) ط¨ظƒط¨ظٹط± ط§ظ„ط³ظ† ({$elderly->E_Name}) ط¨ظ†ط¬ط§ط­!",
            'caregiver' => $caregiver,
            'elderly' => $elderly
        ]);
    }
}

