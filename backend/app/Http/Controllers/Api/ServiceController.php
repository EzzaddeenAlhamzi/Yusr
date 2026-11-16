<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Models\TypeOfCare;
use Illuminate\Http\Request;

class ServiceController extends Controller
{
    /**
     * ظ‚ط§ط¦ظ…ط© ط§ظ„ط®ط¯ظ…ط§طھ ط§ظ„ظ…طھط§ط­ط©
     */
    public function getServices()
    {
        $services = Service::all()->map(function ($s) {
            return [
                'Service_ID'    => $s->Service_ID,
                'S_Name'        => $s->S_Name,
                'Service_Name'  => $s->S_Name,        // alias ظ„ظ„طھظˆط§ظپظ‚ ظ…ط¹ Flutter
                'S_Type'        => $s->S_Type,
                'S_Description' => $s->S_Description,
                'Description'   => $s->S_Description, // alias ظ„ظ„طھظˆط§ظپظ‚ ظ…ط¹ Flutter
                'S_Status'      => $s->S_Status,
                'Admin_ID'      => $s->Admin_ID,
            ];
        });

        return response()->json([
            'status' => 'success',
            'data'   => $services
        ]);
    }

    /**
     * طھظ‚ط¯ظٹظ… ط·ظ„ط¨ ط®ط¯ظ…ط©
     */
    public function requestService(Request $request)
    {
        $serviceId = $request->input('Service_ID');
        $caregiverId = $request->input('Caregivers_id');
        $elderlyId = $request->input('Elderly_ID');
        $note = $request->input('Requst_Note', '');

        $req = ServiceRequest::create([
            'Requst_Date' => now()->format('Y-m-d'),
            'Requst_Status' => 'ظ‚ظٹط¯ ط§ظ„ط§ظ†طھط¸ط§ط±',
            'Requst_Note' => $note,
            'Service_ID' => $serviceId,
            'Caregivers_id' => $caregiverId,
            'Elderly_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھظ‚ط¯ظٹظ… ط·ظ„ط¨ ط§ظ„ط®ط¯ظ…ط© ط¨ظ†ط¬ط§ط­ ظˆظ‡ظˆ ظ‚ظٹط¯ ط§ظ„ظ…ط±ط§ط¬ط¹ط©',
            'data' => $req
        ], 201);
    }

    /**
     * ط¬ظ„ط¨ ط·ظ„ط¨ط§طھ ط§ظ„ط®ط¯ظ…ط§طھ
     */
    public function getServiceRequests(Request $request)
    {
        $caregiverId = $request->query('Caregivers_id', $request->input('Caregivers_id'));
        $elderlyId = $request->query('Elderly_ID', $request->input('Elderly_ID'));

        $query = ServiceRequest::with('service');
        if ($caregiverId) {
            $query->where('Caregivers_id', $caregiverId);
        }
        if ($elderlyId) {
            $query->where('Elderly_ID', $elderlyId);
        }

        $requests = $query->orderBy('Service_Requst_ID', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $requests
        ]);
    }

    /**
     * ط¬ظ„ط¨ ط£ظ†ظˆط§ط¹ ط§ظ„ط±ط¹ط§ظٹط© ط§ظ„ظ…ط­ط¯ط¯ط©
     */
    public function getTypeOfCare(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $query = TypeOfCare::query();
        if ($elderlyId) {
            $query->where('Eldery_ID', $elderlyId);
        }

        $list = $query->orderBy('Tc_id', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $list
        ]);
    }

    /**
     * ط¥ط¶ط§ظپط© ظ†ظˆط¹ ط±ط¹ط§ظٹط©
     */
    public function storeTypeOfCare(Request $request)
    {
        $careType = trim($request->input('Care_Type', ''));
        $caregiverId = $request->input('Caregivers_ID');
        $elderlyId = $request->input('Eldery_ID', $request->input('Elderly_ID'));

        if (empty($careType)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظ†ظˆط¹ ط§ظ„ط±ط¹ط§ظٹط© ظ…ط·ظ„ظˆط¨'
            ], 200);
        }

        $item = TypeOfCare::create([
            'Care_Type' => $careType,
            'Caregivers_ID' => $caregiverId,
            'Eldery_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ…طھ ط¥ط¶ط§ظپط© ظ†ظˆط¹ ط§ظ„ط±ط¹ط§ظٹط© ط¨ظ†ط¬ط§ط­',
            'data' => $item
        ], 201);
    }
}

