<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class CaregiverController extends Controller
{
    public function show($id)
    {
        $caregiver = Caregiver::find($id);

        if (!$caregiver) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط© ط؛ظٹط± ظ…ظˆط¬ظˆط¯'
            ], 200);
        }

        return response()->json([
            'status' => 'success',
            'data' => $caregiver
        ]);
    }

    public function update(Request $request, $id = null)
    {
        $caregiverId = $id ?? $request->input('Caregivers_ID');
        $caregiver = Caregiver::find($caregiverId);

        if (!$caregiver) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط© ط؛ظٹط± ظ…ظˆط¬ظˆط¯'
            ], 200);
        }

        $fields = [];
        if ($request->has('C_Name')) $fields['C_Name'] = $request->input('C_Name');
        if ($request->has('C_PhonNumber')) $fields['C_PhonNumber'] = $request->input('C_PhonNumber');
        if ($request->has('C_Relationship')) $fields['C_Relationship'] = $request->input('C_Relationship');
        if ($request->has('C_Email')) $fields['C_Email'] = $request->input('C_Email');
        if ($request->has('C_Password') && !empty($request->input('C_Password'))) {
            $fields['C_Password'] = Hash::make($request->input('C_Password'));
        }

        $caregiver->update($fields);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھط­ط¯ظٹط« ط¨ظٹط§ظ†ط§طھ ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط© ط¨ظ†ط¬ط§ط­',
            'data' => $caregiver
        ]);
    }
}

