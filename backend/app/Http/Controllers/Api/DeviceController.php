<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Device;
use Illuminate\Http\Request;

class DeviceController extends Controller
{
    public function index(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $query = Device::query();
        if ($elderlyId) {
            $query->where('Elderly_ID', $elderlyId);
        }

        $devices = $query->orderBy('Devices_ID', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $devices
        ]);
    }

    public function store(Request $request)
    {
        $type = trim($request->input('D_Type', 'ط³ط§ط¹ط© ط°ظƒظٹط©'));
        $serial = trim($request->input('T_Number', ''));
        $elderlyId = $request->input('Elderly_ID');

        if (empty($serial)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ظ„ط±ظ‚ظ… ط§ظ„طھط³ظ„ط³ظ„ظٹ ظ„ظ„ط¬ظ‡ط§ط² ظ…ط·ظ„ظˆط¨'
            ], 200);
        }

        $device = Device::create([
            'D_Type' => $type,
            'T_Number' => $serial,
            'Elderly_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… ط±ط¨ط· ط§ظ„ط¬ظ‡ط§ط² ط¨ظ†ط¬ط§ط­',
            'data' => $device
        ], 201);
    }

    public function destroy($id = null, Request $request = null)
    {
        $deviceId = $id ?? ($request ? $request->input('Devices_ID') : null);
        $device = Device::find($deviceId);

        if (!$device) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ظ„ط¬ظ‡ط§ط² ط؛ظٹط± ظ…ظˆط¬ظˆط¯'
            ], 200);
        }

        $device->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… ط­ط°ظپ ط§ظ„ط¬ظ‡ط§ط² ط¨ظ†ط¬ط§ط­'
        ]);
    }
}

