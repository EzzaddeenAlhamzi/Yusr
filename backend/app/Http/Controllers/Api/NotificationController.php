<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\Notification;
use App\Support\YusrAccess;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $query = Notification::query();

        if ($actor instanceof Caregiver) {
            $caregiverId = (int) $actor->Caregivers_ID;
            $requestedCg = $request->query('caregiver_id', $request->query('Caregiver_ID', $request->input('caregiver_id', $request->input('Caregiver_ID'))));
            if ($requestedCg !== null && (int) $requestedCg !== $caregiverId) {
                return YusrAccess::forbidden('غير مصرح بعرض إشعارات مقدم رعاية آخر');
            }

            $elderlyIds = YusrAccess::accessibleElderlyIds($actor);
            $query->where(function ($q) use ($caregiverId, $elderlyIds) {
                $q->where('Caregiver_ID', $caregiverId);
                if ($elderlyIds !== []) {
                    $q->orWhereIn('Eldery_ID', $elderlyIds);
                }
            });
        } else {
            $elderlyId = (int) $actor->Eldery_ID;
            $requestedEl = YusrAccess::resolveElderlyId($request);
            if ($requestedEl !== null && $requestedEl !== $elderlyId) {
                return YusrAccess::forbidden('غير مصرح بعرض إشعارات كبير سن آخر');
            }
            $query->where('Eldery_ID', $elderlyId);
        }

        $notifications = $query->orderBy('Notifications_ID', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $notifications,
        ]);
    }

    public function store(Request $request)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $title = trim($request->input('N_Title', ''));
        $message = trim($request->input('N_Message', ''));
        $type = $request->input('N_Type', 'عام');

        if (empty($title) || empty($message)) {
            return response()->json([
                'status' => 'error',
                'message' => 'عنوان الإشعار ونصه مطلوبان',
            ], 200);
        }

        $caregiverId = $request->input('Caregiver_ID');
        $elderlyId = $request->input('Eldery_ID', $request->input('Elderly_ID'));

        if ($actor instanceof Caregiver) {
            $caregiverId = (int) $actor->Caregivers_ID;
            if ($elderlyId !== null && $elderlyId !== '' && ! YusrAccess::canAccessElderly($actor, $elderlyId)) {
                return YusrAccess::forbidden('غير مصرح بإنشاء إشعار لكبير سن غير مرتبط');
            }
            if ($elderlyId === null || $elderlyId === '') {
                $elderlyId = $actor->Eldery_ID;
            }
        } else {
            $elderlyId = (int) $actor->Eldery_ID;
            // Elderly cannot spoof caregiver destination.
            if ($caregiverId !== null && $caregiverId !== '') {
                if (! YusrAccess::canViewCaregiver($actor, $caregiverId)) {
                    return YusrAccess::forbidden('غير مصرح بإرسال إشعار لمقدم رعاية غير مرتبط');
                }
            } else {
                $caregiverId = null;
            }
        }

        $notification = Notification::create([
            'N_Title' => $title,
            'N_Message' => $message,
            'N_Type' => $type,
            'N_Date' => now()->format('Y-m-d'),
            'N_Time' => now()->format('H:i:s'),
            'N_Status' => 'غير مقروء',
            'Caregiver_ID' => $caregiverId,
            'Eldery_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تم إنشاء الإشعار بنجاح',
            'data' => $notification,
        ], 201);
    }
}
