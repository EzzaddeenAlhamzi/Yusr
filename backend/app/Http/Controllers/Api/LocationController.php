<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LocationTracking;
use App\Models\SafeZone;
use App\Support\YusrAccess;
use Illuminate\Http\Request;

class LocationController extends Controller
{
    public function current(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $location = LocationTracking::where('Elderly_ID', $gated)
            ->orderBy('Location_ID', 'desc')
            ->first();

        if ($location) {
            $data = $location->toArray();
            $data['latitude'] = $location->L_Latitude;
            $data['Longitude'] = $location->L_Longitude;
            $data['longitude'] = $location->L_Longitude;
        } else {
            $data = null;
        }

        return response()->json([
            'status' => 'success',
            'data' => $data,
        ]);
    }

    public function store(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $lat = $request->input('L_Latitude', $request->input('latitude'));
        $lng = $request->input('L_Longitude', $request->input('Longitude'));
        $score = $request->input('L_Scor', 100);

        if (! $lat || ! $lng) {
            return response()->json([
                'status' => 'error',
                'message' => 'بيانات الموقع ومعرف كبير السن مطلوبة',
            ], 200);
        }

        $location = LocationTracking::create([
            'L_Latitude' => $lat,
            'L_Longitude' => $lng,
            'L_UpdateTime' => now(),
            'L_Scor' => $score,
            'Elderly_ID' => $gated,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تم تحديث الموقع الجغرافي بنجاح',
            'data' => $location,
        ], 201);
    }

    public function history(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $locations = LocationTracking::where('Elderly_ID', $gated)
            ->orderBy('Location_ID', 'desc')
            ->limit(20)
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $locations,
        ]);
    }

    public function getSafeZones(Request $request)
    {
        $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $zones = SafeZone::where('Zldery_ID', $gated)
            ->orderBy('Zone_ID', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $zones,
        ]);
    }
}
