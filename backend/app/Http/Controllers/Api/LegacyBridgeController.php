<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class LegacyBridgeController extends Controller
{
    protected AuthController $auth;
    protected CaregiverController $caregiver;
    protected ElderlyController $elderly;
    protected MedicationController $medication;
    protected AppointmentController $appointment;
    protected HealthController $health;
    protected EmergencyController $emergency;
    protected DeviceController $device;
    protected LocationController $location;
    protected NotificationController $notification;
    protected ServiceController $service;
    protected AiVoiceAssistantController $ai;

    public function __construct(
        AuthController $auth,
        CaregiverController $caregiver,
        ElderlyController $elderly,
        MedicationController $medication,
        AppointmentController $appointment,
        HealthController $health,
        EmergencyController $emergency,
        DeviceController $device,
        LocationController $location,
        NotificationController $notification,
        ServiceController $service,
        AiVoiceAssistantController $ai
    ) {
        $this->auth = $auth;
        $this->caregiver = $caregiver;
        $this->elderly = $elderly;
        $this->medication = $medication;
        $this->appointment = $appointment;
        $this->health = $health;
        $this->emergency = $emergency;
        $this->device = $device;
        $this->location = $location;
        $this->notification = $notification;
        $this->service = $service;
        $this->ai = $ai;
    }

    public function handle(Request $request)
    {
        $action = $request->input('action', $request->query('action', 'ping'));

        switch ($action) {
            case 'ping':
                return response()->json([
                    'status' => 'success',
                    'message' => 'تم الاتصال بقاعدة البيانات عبر Laravel API بنجاح!',
                    'database' => config('database.connections.mysql.database'),
                    'framework' => 'Laravel ' . app()->version(),
                ]);

            case 'register_caregiver':
                return $this->auth->registerCaregiver($request);
            case 'login_caregiver':
                return $this->auth->loginCaregiver($request);
            case 'logout':
                return $this->auth->logout($request);
            case 'me':
            case 'auth_me':
                return $this->auth->me($request);
            case 'get_caregiver':
                return $this->caregiver->show($request);
            case 'update_caregiver':
                return $this->caregiver->update($request);

            case 'register_elderly':
                return $this->auth->registerElderly($request);
            case 'login_elderly':
                return $this->auth->loginElderly($request);
            case 'forgot_password':
                return $this->auth->forgotPassword($request);
            case 'get_elderly':
                return $this->elderly->show($request);
            case 'update_elderly':
                return $this->elderly->update($request);
            case 'generate_linking_code':
            case 'create_linking_code':
                return $this->elderly->generateLinkingCode($request);
            case 'link_elderly':
                return $this->elderly->linkCaregiver($request);

            case 'get_medications':
                return $this->medication->index($request);
            case 'add_medication':
                return $this->medication->store($request);
            case 'update_medication':
                return $this->medication->update($request);
            case 'delete_medication':
                return $this->medication->destroy(null, $request);
            case 'get_medication_doses_today':
            case 'get_today_doses':
                return $this->medication->todayDoses($request);
            case 'get_medication_adherence_history':
            case 'get_adherence_history':
                return $this->medication->adherenceHistory($request);
            case 'confirm_medication_dose':
            case 'confirm_dose':
                return $this->medication->confirmDose($request);

            case 'get_appointments':
                return $this->appointment->index($request);
            case 'add_appointment':
                return $this->appointment->store($request);
            case 'update_appointment':
                return $this->appointment->update($request);
            case 'delete_appointment':
                return $this->appointment->destroy(null, $request);

            case 'get_emergency_contacts':
                return $this->emergency->getContacts($request);
            case 'add_emergency_contact':
                return $this->emergency->storeContact($request);
            case 'delete_emergency_contact':
                return $this->emergency->destroyContact(null, $request);

            case 'get_devices':
                return $this->device->index($request);
            case 'add_device':
                return $this->device->store($request);
            case 'delete_device':
                return $this->device->destroy(null, $request);

            case 'get_health_monitoring':
                return $this->health->getRecords($request);
            case 'add_health_record':
                return $this->health->storeRecord($request);
            case 'get_health_alerts':
                return $this->health->getAlerts($request);
            case 'add_health_alert':
                return $this->health->storeAlert($request);

            case 'get_emergency_log':
                return $this->emergency->getLogs($request);
            case 'add_emergency_log':
                return $this->emergency->storeLog($request);
            case 'update_emergency_status':
                return $this->emergency->updateStatus($request);

            case 'get_location':
                return $this->location->current($request);
            case 'update_location':
                return $this->location->store($request);
            case 'get_location_history':
                return $this->location->history($request);
            case 'get_safe_zones':
                return $this->location->getSafeZones($request);

            case 'get_notifications':
                return $this->notification->index($request);
            case 'add_notification':
                return $this->notification->store($request);
            case 'mark_notification_read':
            case 'read_notification':
                return $this->notification->markRead($request);

            case 'get_type_of_care':
                return $this->service->getTypeOfCare($request);
            case 'add_type_of_care':
                return $this->service->storeTypeOfCare($request);
            case 'get_services':
                return $this->service->getServices();
            case 'request_service':
                return $this->service->requestService($request);
            case 'get_service_requests':
                return $this->service->getServiceRequests($request);

            case 'voice_assistant':
            case 'ask_ai':
                return $this->ai->ask($request);

            default:
                return response()->json([
                    'status' => 'error',
                    'message' => "الإجراء المطلوب ({$action}) غير معروف في Laravel API",
                ], 200);
        }
    }
}
