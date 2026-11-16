<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LocationTracking;
use App\Models\SafeZone;
use Illuminate\Http\Request;

class LocationController extends Controller
{
    /**
     * ط¬ظ„ط¨ ط¢ط®ط± ظ…ظˆظ‚ط¹ ظ…ط³ط¬ظ„ ظ„ظƒط¨ظٹط± ط§ظ„ط³ظ†
     */
    public function current(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $location = LocationTracking::where('Elderly_ID', $elderlyId)
            ->orderBy('Location_ID', 'desc')
            ->first();

        if ($location) {
            $data = $location->toArray();
            // ط¥ط¶ط§ظپط© aliases ظ„ظ„طھظˆط§ظپظ‚ ظ…ط¹ ظƒظˆط¯ Flutter ط§ظ„ظ‚ط¯ظٹظ…
            $data['latitude']  = $location->L_Latitude;
            $data['Longitude'] = $location->L_Longitude;
            $data['longitude'] = $location->L_Longitude;
        } else {
            $data = null;
        }

        return response()->json([
            'status' => 'success',
            'data'   => $data
        ]);
    }

    /**
     * طھط­ط¯ظٹط« ظˆطھط³ط¬ظٹظ„ ط§ظ„ظ…ظˆظ‚ط¹ ط§ظ„ط­ط§ظ„ظٹ
     */
    public function store(Request $request)
    {
        $elderlyId = $request->input('Elderly_ID');
        $lat = $request->input('L_Latitude', $request->input('latitude'));
        $lng = $request->input('L_Longitude', $request->input('Longitude'));
        $score = $request->input('L_Scor', 100);

        if (!$elderlyId || !$lat || !$lng) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ…ظˆظ‚ط¹ ظˆظ…ط¹ط±ظپ ظƒط¨ظٹط± ط§ظ„ط³ظ† ظ…ط·ظ„ظˆط¨ط©'
            ], 200);
        }

        $location = LocationTracking::create([
            'L_Latitude' => $lat,
            'L_Longitude' => $lng,
            'L_UpdateTime' => now(),
            'L_Scor' => $score,
            'Elderly_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھط­ط¯ظٹط« ط§ظ„ظ…ظˆظ‚ط¹ ط§ظ„ط¬ط؛ط±ط§ظپظٹ ط¨ظ†ط¬ط§ط­',
            'data' => $location
        ], 201);
    }

    /**
     * ط³ط¬ظ„ طھظ†ظ‚ظ„ط§طھ ظˆظ…ظˆط§ظ‚ط¹ ظƒط¨ظٹط± ط§ظ„ط³ظ†
     */
    public function history(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $locations = LocationTracking::where('Elderly_ID', $elderlyId)
            ->orderBy('Location_ID', 'desc')
            ->limit(20)
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $locations
        ]);
    }

    /**
     * ط§ظ„ظ†ط·ط§ظ‚ط§طھ ط§ظ„ط¢ظ…ظ†ط©
     */
    public function getSafeZones(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $zones = SafeZone::where('Zldery_ID', $elderlyId)
            ->orderBy('Zone_ID', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $zones
        ]);
    }
}

