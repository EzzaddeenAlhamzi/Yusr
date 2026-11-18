<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Models\TypeOfCare;
use App\Support\YusrAccess;
use Illuminate\Http\Request;

class ServiceController extends Controller
{
    public function getServices()
    {
        $services = Service::all()->map(function ($s) {
            return [
                'Service_ID' => $s->Service_ID,
                'S_Name' => $s->S_Name,
                'Service_Name' => $s->S_Name,
                'S_Type' => $s->S_Type,
                'S_Description' => $s->S_Description,
                'Description' => $s->S_Description,
                'S_Status' => $s->S_Status,
                'Admin_ID' => $s->Admin_ID,
            ];
        });

        return response()->json([
            'status' => 'success',
            'data' => $services,
        ]);
    }

    public function requestService(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $serviceId = $request->input('Service_ID');
        $note = $request->input('Requst_Note', '');

        if ($actor instanceof Caregiver) {
            $caregiverId = (int) $actor->Caregivers_ID;
            $gated = YusrAccess::gateElderly($request, YusrAccess::resolveElderlyId($request), true);
            if ($gated instanceof \Illuminate\Http\JsonResponse) {
                return $gated;
            }
            $elderlyId = $gated;
        } else {
            $elderlyId = (int) $actor->Eldery_ID;
            $caregiverId = $request->input('Caregivers_id');
            if ($caregiverId !== null && $caregiverId !== '' && ! YusrAccess::canViewCaregiver($actor, $caregiverId)) {
                return YusrAccess::forbidden('غير مصرح بربط طلب الخدمة بمقدم رعاية غير مرتبط');
            }
            if ($caregiverId === null || $caregiverId === '') {
                $linked = Caregiver::query()->where('Eldery_ID', $elderlyId)->value('Caregivers_ID');
                $caregiverId = $linked;
            }
        }

        $req = ServiceRequest::create([
            'Requst_Date' => now()->format('Y-m-d'),
            'Requst_Status' => 'قيد الانتظار',
            'Requst_Note' => $note,
            'Service_ID' => $serviceId,
            'Caregivers_id' => $caregiverId,
            'Elderly_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تم تقديم طلب الخدمة بنجاح وهو قيد المراجعة',
            'data' => $req,
        ], 201);
    }

    public function getServiceRequests(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $query = ServiceRequest::with('service');

        if ($actor instanceof Caregiver) {
            $elderlyIds = YusrAccess::accessibleElderlyIds($actor);
            $query->where(function ($q) use ($actor, $elderlyIds) {
                $q->where('Caregivers_id', $actor->Caregivers_ID);
                if ($elderlyIds !== []) {
                    $q->orWhereIn('Elderly_ID', $elderlyIds);
                }
            });
        } else {
            $query->where('Elderly_ID', $actor->Eldery_ID);
        }

        $requests = $query->orderBy('Service_Requst_ID', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $requests,
        ]);
    }

    public function getTypeOfCare(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $requested = YusrAccess::resolveElderlyId($request);
        $allowed = YusrAccess::accessibleElderlyIds($actor);

        if ($requested !== null) {
            if (! in_array($requested, $allowed, true)) {
                return YusrAccess::forbidden('غير مصرح بالوصول إلى أنواع الرعاية');
            }
            $scope = [$requested];
        } else {
            $scope = $allowed;
        }

        if ($scope === []) {
            $list = collect();
        } else {
            $list = TypeOfCare::query()
                ->whereIn('Eldery_ID', $scope)
                ->orderBy('Tc_id', 'desc')
                ->get();
        }

        return response()->json([
            'status' => 'success',
            'data' => $list,
        ]);
    }

    public function storeTypeOfCare(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $careType = trim($request->input('Care_Type', ''));
        if (empty($careType)) {
            return response()->json([
                'status' => 'error',
                'message' => 'نوع الرعاية مطلوب',
            ], 200);
        }

        $gated = YusrAccess::gateElderly(
            $request,
            YusrAccess::resolveElderlyId($request, $request->input('Eldery_ID')),
            true
        );
        if ($gated instanceof \Illuminate\Http\JsonResponse) {
            return $gated;
        }

        $caregiverId = $actor instanceof Caregiver
            ? (int) $actor->Caregivers_ID
            : $request->input('Caregivers_ID');

        if ($actor instanceof \App\Models\Elderly && $caregiverId !== null && $caregiverId !== '') {
            if (! YusrAccess::canViewCaregiver($actor, $caregiverId)) {
                return YusrAccess::forbidden('غير مصرح بربط نوع الرعاية بمقدم رعاية غير مرتبط');
            }
        }

        $item = TypeOfCare::create([
            'Care_Type' => $careType,
            'Caregivers_ID' => $caregiverId,
            'Eldery_ID' => $gated,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تمت إضافة نوع الرعاية بنجاح',
            'data' => $item,
        ], 201);
    }
}
