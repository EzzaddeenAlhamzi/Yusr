<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\Notification;
use App\Services\CaregiverOverdueAlertService;
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

            // Isolation: caregiver sees only rows addressed to them.
            $query->where('Caregiver_ID', $caregiverId);

            $requestedEl = YusrAccess::resolveElderlyId($request);
            if ($requestedEl !== null) {
                if (! YusrAccess::canAccessElderly($actor, $requestedEl)) {
                    return YusrAccess::forbidden('غير مصرح بعرض إشعارات كبير سن غير مرتبط');
                }
                $query->where('Eldery_ID', $requestedEl);
            }
        } else {
            $elderlyId = (int) $actor->Eldery_ID;
            $requestedEl = YusrAccess::resolveElderlyId($request);
            if ($requestedEl !== null && $requestedEl !== $elderlyId) {
                return YusrAccess::forbidden('غير مصرح بعرض إشعارات كبير سن آخر');
            }
            // M-1: elderly must not list caregiver-only Channel B overdue alerts
            // (those rows also set Eldery_ID for linkage context).
            $query->where('Eldery_ID', $elderlyId)
                ->where(function ($q) {
                    $q->whereNull('event_type')
                        ->orWhere('event_type', '!=', CaregiverOverdueAlertService::EVENT_TYPE);
                });
        }

        $unreadOnly = $request->query('unread_only', $request->input('unread_only'));
        if ($unreadOnly === '1' || $unreadOnly === 1 || $unreadOnly === true || $unreadOnly === 'true') {
            $query->where(function ($q) {
                $q->where('N_Status', Notification::STATUS_UNREAD)
                    ->orWhere('N_Status', 'unread')
                    ->orWhere('N_Status', 'جديد')
                    ->orWhereNull('N_Status')
                    ->orWhere('N_Status', '');
            });
        }

        $notifications = $query->orderBy('Notifications_ID', 'desc')->get();

        $unreadCount = 0;
        foreach ($notifications as $n) {
            if ($n->isUnread()) {
                $unreadCount++;
            }
        }

        return response()->json([
            'status' => 'success',
            'data' => $notifications,
            'unread_count' => $unreadCount,
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
            if ($elderlyId === null || $elderlyId === '') {
                return response()->json([
                    'status' => 'error',
                    'message' => 'لا يوجد كبير سن مرتبط لإرسال التنبيه',
                    'error_type' => 'no_linked_elderly',
                ], 200);
            }
        } else {
            $elderlyId = (int) $actor->Eldery_ID;
            if ($caregiverId !== null && $caregiverId !== '') {
                if (! YusrAccess::canViewCaregiver($actor, $caregiverId)) {
                    return YusrAccess::forbidden('غير مصرح بإرسال إشعار لمقدم رعاية غير مرتبط');
                }
            } else {
                $caregiverId = null;
            }
        }

        // M-2: event_type / occurrence_key / DoseOccurrence_ID are server/job-only
        // (CaregiverOverdueAlertService). Clients must not poison unique keys.
        // Urgent Option A in-app reminders still work via title/message/type only.
        $notification = Notification::create([
            'N_Title' => $title,
            'N_Message' => $message,
            'N_Type' => $type,
            'event_type' => null,
            'occurrence_key' => null,
            'DoseOccurrence_ID' => null,
            'N_Date' => now()->format('Y-m-d'),
            'N_Time' => now()->format('H:i:s'),
            'N_Status' => Notification::STATUS_UNREAD,
            'Caregiver_ID' => $caregiverId,
            'Eldery_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'تم إنشاء الإشعار بنجاح',
            'data' => $notification,
        ], 201);
    }

    public function markRead(Request $request, $id = null)
    {
        $actor = YusrAccess::requireActor($request);
        if ($actor instanceof \Illuminate\Http\JsonResponse) {
            return $actor;
        }

        $id = $id ?? $request->input('Notifications_ID', $request->input('id'));
        $id = (int) $id;
        if ($id <= 0) {
            return response()->json([
                'status' => 'error',
                'message' => 'معرّف الإشعار مطلوب',
            ], 200);
        }

        $notification = Notification::query()->where('Notifications_ID', $id)->first();
        if (! $notification) {
            return YusrAccess::notFound('الإشعار غير موجود');
        }

        if ($actor instanceof Caregiver) {
            if ((int) $notification->Caregiver_ID !== (int) $actor->Caregivers_ID) {
                return YusrAccess::forbidden('غير مصرح بتحديث إشعار مقدم رعاية آخر');
            }
        } else {
            // M-1: caregiver-only overdue alerts are not markable by elderly
            // even when Eldery_ID matches for fan-out context.
            if ((string) $notification->event_type === CaregiverOverdueAlertService::EVENT_TYPE) {
                return YusrAccess::forbidden('غير مصرح بتحديث تنبيه مخصص لمقدم الرعاية');
            }
            if ((int) $notification->Eldery_ID !== (int) $actor->Eldery_ID) {
                return YusrAccess::forbidden('غير مصرح بتحديث إشعار كبير سن آخر');
            }
        }

        $notification->markRead();

        return response()->json([
            'status' => 'success',
            'message' => 'تم تعليم الإشعار كمقروء',
            'data' => $notification->fresh(),
        ]);
    }
}
