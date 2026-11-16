<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HealthAlert;
use App\Models\HealthMonitoring;
use Illuminate\Http\Request;

class HealthController extends Controller
{
    /**
     * ط¬ظ„ط¨ ط³ط¬ظ„ط§طھ ط§ظ„ظ…طھط§ط¨ط¹ط© ط§ظ„طµط­ظٹط©
     */
    public function getRecords(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $query = HealthMonitoring::query();
        if ($elderlyId) {
            $query->where('Elderly_ID', $elderlyId);
        }

        $records = $query->orderBy('H_Record_ID', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $records
        ]);
    }

    /**
     * ط¥ط¶ط§ظپط© ظ‚ط±ط§ط،ط© طµط­ظٹط© ط¬ط¯ظٹط¯ط© ظ…ط¹ ط§ظ„ظپط­طµ ط§ظ„طھظ„ظ‚ط§ط¦ظٹ ظ„ظ„ط­ط¯ظˆط¯ ط§ظ„ظ…ط¹طھظ…ط¯ط©
     */
    public function storeRecord(Request $request)
    {
        $elderlyId = $request->input('Elderly_ID');
        $heartRate = $request->input('Heart_Rate');
        $bloodPressure = $request->input('Blood_pressure');
        $oxygen = $request->input('Oxyger');
        $temp = $request->input('Temperature');
        $steps = $request->input('steps', 0);
        $hType = $request->input('H_Type', 'ظ‚ط±ط§ط،ط© ط±ظˆطھظٹظ†ظٹط©');
        $hDate = $request->input('H_Date', now()->format('Y-m-d'));
        $hResult = $request->input('H_Result', 'ط·ط¨ظٹط¹ظٹ');
        $deviceId = $request->input('Devices_ID');
        $emergencyId = $request->input('Emergency_ID');

        $record = HealthMonitoring::create([
            'Heart_Rate' => $heartRate,
            'Blood_pressure' => $bloodPressure,
            'Oxyger' => $oxygen,
            'Temperature' => $temp,
            'steps' => $steps,
            'H_Type' => $hType,
            'H_Date' => $hDate,
            'H_Result' => $hResult,
            'Elderly_ID' => $elderlyId,
            'Devices_ID' => $deviceId,
            'Emergency_ID' => $emergencyId,
        ]);

        // ط§ظ„ظپط­طµ ط§ظ„طھظ„ظ‚ط§ط¦ظٹ ظˆطھظˆظ„ظٹط¯ طھظ†ط¨ظٹظ‡ طµط­ظٹ ط¥ط°ط§ ظƒط§ظ†طھ ط§ظ„ظ‚ط±ط§ط،ط§طھ ط­ط±ط¬ط©
        $alertCreated = null;
        if (($heartRate && ($heartRate > 105 || $heartRate < 55)) ||
            ($oxygen && $oxygen < 92) ||
            ($temp && $temp > 38.0)) {
            
            $alertDesc = [];
            if ($heartRate && $heartRate > 105) $alertDesc[] = "ط§ط±طھظپط§ط¹ ظ†ط¨ط¶ط§طھ ط§ظ„ظ‚ظ„ط¨ ({$heartRate} ظ†ط¨ط¶ط©/ط¯)";
            if ($heartRate && $heartRate < 55) $alertDesc[] = "ط§ظ†ط®ظپط§ط¶ ظ†ط¨ط¶ط§طھ ط§ظ„ظ‚ظ„ط¨ ({$heartRate} ظ†ط¨ط¶ط©/ط¯)";
            if ($oxygen && $oxygen < 92) $alertDesc[] = "ط§ظ†ط®ظپط§ط¶ طھط´ط¨ط¹ ط§ظ„ط£ظƒط³ط¬ظٹظ† ({$oxygen}%)";
            if ($temp && $temp > 38.0) $alertDesc[] = "ط§ط±طھظپط§ط¹ ط¯ط±ط¬ط© ط§ظ„ط­ط±ط§ط±ط© ({$temp}آ°C)";

            $alertCreated = HealthAlert::create([
                'A_Type' => 'ظ…ط¤ط´ط±ط§طھ طµط­ظٹط© ط؛ظٹط± ط·ط¨ظٹط¹ظٹط©',
                'A_Description' => implode('طŒ ', $alertDesc),
                'A_Level' => 'ط­ط±ط¬',
                'A_Date' => now()->format('Y-m-d'),
                'A_Status' => 'ط؛ظٹط± ظ…ط¹ط§ظ„ط¬',
                'H_Record_ID' => $record->H_Record_ID,
            ]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھط³ط¬ظٹظ„ ط§ظ„ظ‚ط±ط§ط،ط© ط§ظ„طµط­ظٹط© ط¨ظ†ط¬ط§ط­',
            'data' => $record,
            'generated_alert' => $alertCreated
        ], 201);
    }

    /**
     * ط¬ظ„ط¨ ط§ظ„طھظ†ط¨ظٹظ‡ط§طھ ط§ظ„طµط­ظٹط©
     */
    public function getAlerts(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $query = HealthAlert::with('healthRecord');

        if ($elderlyId) {
            $query->whereHas('healthRecord', function ($q) use ($elderlyId) {
                $q->where('Elderly_ID', $elderlyId);
            });
        }

        $alerts = $query->orderBy('Alert_ID', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $alerts
        ]);
    }

    /**
     * ط¥ط¶ط§ظپط© طھظ†ط¨ظٹظ‡ طµط­ظٹ ظٹط¯ظˆظٹط§ظ‹
     */
    public function storeAlert(Request $request)
    {
        $type = $request->input('A_Type', 'طھظ†ط¨ظٹظ‡ طµط­ظٹ');
        $desc = $request->input('A_Description', '');
        $level = $request->input('A_Level', 'ظ…طھظˆط³ط·');
        $status = $request->input('A_Status', 'ط؛ظٹط± ظ…ط¹ط§ظ„ط¬');
        $hRecordId = $request->input('H_Record_ID');

        $alert = HealthAlert::create([
            'A_Type' => $type,
            'A_Description' => $desc,
            'A_Level' => $level,
            'A_Date' => now()->format('Y-m-d'),
            'A_Status' => $status,
            'H_Record_ID' => $hRecordId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… ط¥ظ†ط´ط§ط، ط§ظ„طھظ†ط¨ظٹظ‡ ط§ظ„طµط­ظٹ ط¨ظ†ط¬ط§ط­',
            'data' => $alert
        ], 201);
    }
}

