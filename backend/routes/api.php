<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CaregiverController;
use App\Http\Controllers\Api\ElderlyController;
use App\Http\Controllers\Api\MedicationController;
use App\Http\Controllers\Api\AppointmentController;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\EmergencyController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\LocationController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\ServiceController;
use App\Http\Controllers\Api\AiVoiceAssistantController;
use App\Http\Controllers\Api\LegacyBridgeController;

/*
|--------------------------------------------------------------------------
| API Routes - Yusr (يُسر) Laravel Backend
|--------------------------------------------------------------------------
*/

// 1. اختبار الاتصال والصحة (Health Check)
Route::match(['get', 'post'], '/ping', function () {
    return response()->json([
        'status' => 'success',
        'message' => 'تم الاتصال بقاعدة البيانات yusr_application عبر Laravel API بنجاح!',
        'database' => config('database.connections.mysql.database'),
        'framework' => 'Laravel ' . app()->version(),
    ]);
});

// 2. المصادقة والحسابات (Authentication)
Route::prefix('auth')->group(function () {
    Route::post('/caregiver/register', [AuthController::class, 'registerCaregiver']);
    Route::post('/caregiver/login', [AuthController::class, 'loginCaregiver']);
    Route::post('/elderly/register', [AuthController::class, 'registerElderly']);
    Route::post('/elderly/login', [AuthController::class, 'loginElderly']);
    Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
});

// 3. مقدم الرعاية (Caregiver)
Route::get('/caregiver/{id}', [CaregiverController::class, 'show']);
Route::match(['put', 'post'], '/caregiver/{id?}', [CaregiverController::class, 'update']);

// 4. كبير السن (Elderly)
Route::get('/elderly/{id}', [ElderlyController::class, 'show']);
Route::match(['put', 'post'], '/elderly/{id?}', [ElderlyController::class, 'update']);
Route::post('/elderly/link', [ElderlyController::class, 'linkCaregiver']);

// 5. الأدوية (Medications)
Route::get('/medications', [MedicationController::class, 'index']);
Route::post('/medications', [MedicationController::class, 'store']);
Route::match(['put', 'post'], '/medications/{id?}', [MedicationController::class, 'update']);
Route::match(['delete', 'post'], '/medications/{id?}/delete', [MedicationController::class, 'destroy']);

// 6. المواعيد (Appointments)
Route::get('/appointments', [AppointmentController::class, 'index']);
Route::post('/appointments', [AppointmentController::class, 'store']);
Route::match(['delete', 'post'], '/appointments/{id?}/delete', [AppointmentController::class, 'destroy']);

// 7. القياسات الصحية والتنبيهات (Health Monitoring & Alerts)
Route::get('/health/records', [HealthController::class, 'getRecords']);
Route::post('/health/records', [HealthController::class, 'storeRecord']);
Route::get('/health/alerts', [HealthController::class, 'getAlerts']);
Route::post('/health/alerts', [HealthController::class, 'storeAlert']);

// 8. الطوارئ وجهات الاتصال (Emergency)
Route::get('/emergency/logs', [EmergencyController::class, 'getLogs']);
Route::post('/emergency/logs', [EmergencyController::class, 'storeLog']);
Route::match(['put', 'post'], '/emergency/logs/{id?}/status', [EmergencyController::class, 'updateStatus']);
Route::get('/emergency/contacts', [EmergencyController::class, 'getContacts']);
Route::post('/emergency/contacts', [EmergencyController::class, 'storeContact']);
Route::match(['delete', 'post'], '/emergency/contacts/{id?}/delete', [EmergencyController::class, 'destroyContact']);

// 9. الأجهزة الذكية (Devices)
Route::get('/devices', [DeviceController::class, 'index']);
Route::post('/devices', [DeviceController::class, 'store']);
Route::match(['delete', 'post'], '/devices/{id?}/delete', [DeviceController::class, 'destroy']);

// 10. التتبع الجغرافي والنطاقات الآمنة (Location & Safe Zones)
Route::get('/location/current', [LocationController::class, 'current']);
Route::post('/location', [LocationController::class, 'store']);
Route::get('/location/history', [LocationController::class, 'history']);
Route::get('/location/safe-zones', [LocationController::class, 'getSafeZones']);

// 11. الإشعارات (Notifications)
Route::get('/notifications', [NotificationController::class, 'index']);
Route::post('/notifications', [NotificationController::class, 'store']);

// 12. الخدمات وأنواع الرعاية (Services & Care Types)
Route::get('/services', [ServiceController::class, 'getServices']);
Route::post('/services/request', [ServiceController::class, 'requestService']);
Route::get('/services/requests', [ServiceController::class, 'getServiceRequests']);
Route::get('/type-of-care', [ServiceController::class, 'getTypeOfCare']);
Route::post('/type-of-care', [ServiceController::class, 'storeTypeOfCare']);

// 13. الذكاء الاصطناعي والمساعد الصوتي الذكي (Gemini AI Voice Assistant)
Route::post('/ai/voice-assistant', [AiVoiceAssistantController::class, 'ask']);
Route::post('/voice-assistant/ask', [AiVoiceAssistantController::class, 'ask']);

// 14. طبقة التوافق الشاملة مع ملف index.php والطلبات القديمة (Legacy Bridge)
Route::match(['get', 'post'], '/legacy', [LegacyBridgeController::class, 'handle']);
Route::match(['get', 'post'], '/bridge', [LegacyBridgeController::class, 'handle']);
