<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HealthAlert;
use App\Models\HealthMonitoring;
use App\Support\YusrAccess;
use Illuminate\Http\Request;

class HealthController extends Controller
{
    public function getRecords(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $requested = YusrAccess::resolveElderlyId($request);
        $allowed = YusrAccess::accessibleElderlyIds($actor);

        if ($requested !== null) {
            if (! in_array($requested, $allowed, true)) {
                return YusrAccess::forbidden('غير مصرح بالوصول إلى السجلات الصحية');
            }
            $scope = [$requested];
        } else {
            $scope = $allowed;
        }

        if ($scope === []) {
            $records = collect();
        } else {
            $records = HealthMonitoring::query()
                ->whereIn('Elderly_ID', $scope)
                ->orderBy('H_Record_ID', 'desc')
                ->get();
        }

        return response()->json([
            'status' => 'success',
            'data' => $records,
        ]);
    }

    public function storeRecord(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $heartRate = $request->input('Heart_Rate');
        $bloodPressure = $request->input('Blood_pressure');
        $oxygen = $request->input('Oxyger');
        $temp = $request->input('Temperature');
        $steps = $request->input('steps', 0);
        $hType = $request->input('H_Type', 'قراءة روتينية');
        $hDate = $request->input('H_Date', now()->format('Y-m-d'));
        $hResult = $request->input('H_Result', 'طبيعية');
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
            'Elderly_ID' => $gated,
            'Devices_ID' => $deviceId,
            'Emergency_ID' => $emergencyId,
        ]);

        $alertCreated = null;
        if (($heartRate && ($heartRate > 105 || $heartRate < 55)) ||
            ($oxygen && $oxygen < 92) ||
            ($temp && $temp > 38.0)) {

            $alertDesc = [];
            if ($heartRate && $heartRate > 105) {
                $alertDesc[] = "ارتفاع نبضات القلب ({$heartRate} نبضة/د)";
            }
            if ($heartRate && $heartRate < 55) {
                $alertDesc[] = "انخفاض نبضات القلب ({$heartRate} نبضة/د)";
            }
            if ($oxygen && $oxygen < 92) {
                $alertDesc[] = "انخفاض تشبع الأكسجين ({$oxygen}%)";
            }
            if ($temp && $temp > 38.0) {
                $alertDesc[] = "ارتفاع درجة الحرارة ({$temp}°C)";
            }

            $alertCreated = HealthAlert::create([
                'A_Type' => 'مؤشرات صحية غير طبيعية',
                'A_Description' => implode('، ', $alertDesc),
                'A_Level' => 'حرج',
                'A_Date' => now()->format('Y-m-d'),
                'A_Status' => 'غير معالج',
                'H_Record_ID' => $record->H_Record_ID,
            ]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'تم تسجيل القراءة الصحية بنجاح',
            'data' => $record,
            'generated_alert' => $alertCreated,
        ], 201);
    }

    public function getAlerts(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $requested = YusrAccess::resolveElderlyId($request);
        $allowed = YusrAccess::accessibleElderlyIds($actor);

        if ($requested !== null) {
            if (! in_array($requested, $allowed, true)) {
                return YusrAccess::forbidden('غير مصرح بالوصول إلى التنبيهات الصحية');
            }
            $scope = [$requested];
        } else {
            $scope = $allowed;
        }

        $query = HealthAlert::with('healthRecord');
        if ($scope === []) {
            $alerts = collect();
        } else {
            $alerts = $query->whereHas('healthRecord', function ($q) use ($scope) {
                $q->whereIn('Elderly_ID', $scope);
            })->orderBy('Alert_ID', 'desc')->get();
        }

        return response()->json([
            'status' => 'success',
            'data' => $alerts,
        ]);
    }

    public function storeAlert(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $hRecordId = $request->input('H_Record_ID');
        if ($hRecordId) {
            $record = HealthMonitoring::find($hRecordId);
            if (! $record || ! YusrAccess::canAccessElderly($actor, $record->Elderly_ID)) {
                return YusrAccess::forbidden('غير مصرح بإنشاء تنبيه لهذا السجل');
            }
        } else {
            // Without a record, require an accessible elderly context.
            $gated = YusrAccess::gateElderly($request, null, true);
            if ($gated instanceof \Illuminate\Http\JsonResponse) {
                return $gated;
            }
        }

        $type = $request->input('A_Type', 'تنبيه صحي');
        $desc = $request->input('A_Description', '');
        $level = $request->input('A_Level', 'متوسط');
        $status = $request->input('A_Status', 'غير معالج');

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
            'message' => 'تم إنشاء التنبيه الصحي بنجاح',
            'data' => $alert,
        ], 201);
    }
}
