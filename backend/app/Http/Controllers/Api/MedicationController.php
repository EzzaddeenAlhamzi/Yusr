<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Medication;
use Illuminate\Http\Request;

class MedicationController extends Controller
{
    public function index(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $query = Medication::query();
        if ($elderlyId) {
            $query->where('Elderly_ID', $elderlyId);
        }

        $medications = $query->orderBy('Medicayion_ID', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $medications
        ]);
    }

    public function store(Request $request)
    {
        $name = trim($request->input('M_Name', ''));
        $much = trim($request->input('M_much', ''));
        $repatTime = trim($request->input('M_RepatTime', ''));
        $elderlyId = $request->input('Elderly_ID');

        if (empty($name)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ط³ظ… ط§ظ„ط¯ظˆط§ط، ظ…ط·ظ„ظˆط¨'
            ], 200);
        }

        $medication = Medication::create([
            'M_Name' => $name,
            'M_much' => $much,
            'M_RepatTime' => $repatTime,
            'Elderly_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ…طھ ط¥ط¶ط§ظپط© ط§ظ„ط¯ظˆط§ط، ط¨ظ†ط¬ط§ط­',
            'data' => $medication
        ], 201);
    }

    public function update(Request $request, $id = null)
    {
        $medId = $id ?? $request->input('Medicayion_ID');
        $medication = Medication::find($medId);

        if (!$medication) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ظ„ط¯ظˆط§ط، ط؛ظٹط± ظ…ظˆط¬ظˆط¯'
            ], 200);
        }

        $fields = [];
        if ($request->has('M_Name')) $fields['M_Name'] = $request->input('M_Name');
        if ($request->has('M_much')) $fields['M_much'] = $request->input('M_much');
        if ($request->has('M_RepatTime')) $fields['M_RepatTime'] = $request->input('M_RepatTime');

        $medication->update($fields);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھط­ط¯ظٹط« ط§ظ„ط¯ظˆط§ط، ط¨ظ†ط¬ط§ط­',
            'data' => $medication
        ]);
    }

    public function destroy($id = null, Request $request = null)
    {
        $medId = $id ?? ($request ? $request->input('Medicayion_ID') : null);
        $medication = Medication::find($medId);

        if (!$medication) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ظ„ط¯ظˆط§ط، ط؛ظٹط± ظ…ظˆط¬ظˆط¯'
            ], 200);
        }

        $medication->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… ط­ط°ظپ ط§ظ„ط¯ظˆط§ط، ط¨ظ†ط¬ط§ط­'
        ]);
    }
}

