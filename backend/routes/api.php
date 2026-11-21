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
| P1.2: public ping + auth; all resource routes require Sanctum + ownership
| checks inside controllers. Legacy/bridge uses legacy.auth (public actions
| only for ping/register/login/forgot).
*/

// 1. اختبار الاتصال والصحة (Health Check) — public
Route::match(['get', 'post'], '/ping', function () {
    $db = config('database.connections.mysql.database');

    return response()->json([
        'status' => 'success',
        'message' => 'تم الاتصال بقاعدة البيانات ' . $db . ' عبر Laravel API بنجاح!',
        'database' => $db,
        'framework' => 'Laravel ' . app()->version(),
    ]);
});

// 2. المصادقة والحسابات (Authentication) — public register/login/forgot
Route::prefix('auth')->group(function () {
    Route::post('/caregiver/register', [AuthController::class, 'registerCaregiver']);
    Route::post('/caregiver/login', [AuthController::class, 'loginCaregiver']);
    Route::post('/elderly/register', [AuthController::class, 'registerElderly']);
    Route::post('/elderly/login', [AuthController::class, 'loginElderly']);
    Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
});

// 3–13. Protected resources (Sanctum AuthN + controller AuthZ)
Route::middleware('auth:sanctum')->group(function () {
    Route::match(['get', 'post'], '/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    // مقدم الرعاية
    Route::get('/caregiver/{id}', [CaregiverController::class, 'show']);
    Route::match(['put', 'post'], '/caregiver/{id?}', [CaregiverController::class, 'update']);

    // كبير السن — linking-code + /link before /{id} so paths are not captured as ids
    Route::post('/elderly/linking-code', [ElderlyController::class, 'generateLinkingCode']);
    Route::post('/elderly/link', [ElderlyController::class, 'linkCaregiver']);
    Route::get('/elderly/{id}', [ElderlyController::class, 'show']);
    Route::match(['put', 'post'], '/elderly/{id?}', [ElderlyController::class, 'update']);

    // الأدوية + التزام الجرعات (P2.2) — dose routes before {id} catch-alls
    Route::get('/medications/doses/today', [MedicationController::class, 'todayDoses']);
    Route::get('/medications/doses/history', [MedicationController::class, 'adherenceHistory']);
    Route::post('/medications/doses/confirm', [MedicationController::class, 'confirmDose']);
    Route::get('/medications', [MedicationController::class, 'index']);
    Route::post('/medications', [MedicationController::class, 'store']);
    Route::match(['put', 'post'], '/medications/{id?}', [MedicationController::class, 'update']);
    Route::match(['delete', 'post'], '/medications/{id?}/delete', [MedicationController::class, 'destroy']);

    // المواعيد
    Route::get('/appointments', [AppointmentController::class, 'index']);
    Route::post('/appointments', [AppointmentController::class, 'store']);
    Route::match(['put', 'post'], '/appointments/{id?}', [AppointmentController::class, 'update']);
    Route::match(['delete', 'post'], '/appointments/{id?}/delete', [AppointmentController::class, 'destroy']);

    // القياسات الصحية والتنبيهات
    Route::get('/health/records', [HealthController::class, 'getRecords']);
    Route::post('/health/records', [HealthController::class, 'storeRecord']);
    Route::get('/health/alerts', [HealthController::class, 'getAlerts']);
    Route::post('/health/alerts', [HealthController::class, 'storeAlert']);

    // الطوارئ وجهات الاتصال
    Route::get('/emergency/logs', [EmergencyController::class, 'getLogs']);
    Route::post('/emergency/logs', [EmergencyController::class, 'storeLog']);
    Route::match(['put', 'post'], '/emergency/logs/{id?}/status', [EmergencyController::class, 'updateStatus']);
    Route::get('/emergency/contacts', [EmergencyController::class, 'getContacts']);
    Route::post('/emergency/contacts', [EmergencyController::class, 'storeContact']);
    Route::match(['delete', 'post'], '/emergency/contacts/{id?}/delete', [EmergencyController::class, 'destroyContact']);

    // الأجهزة الذكية
    Route::get('/devices', [DeviceController::class, 'index']);
    Route::post('/devices', [DeviceController::class, 'store']);
    Route::match(['delete', 'post'], '/devices/{id?}/delete', [DeviceController::class, 'destroy']);

    // التتبع الجغرافي والنطاقات الآمنة
    Route::get('/location/current', [LocationController::class, 'current']);
    Route::post('/location', [LocationController::class, 'store']);
    Route::get('/location/history', [LocationController::class, 'history']);
    Route::get('/location/safe-zones', [LocationController::class, 'getSafeZones']);

    // الإشعارات (P2.3: list + create + mark-read; no FCM)
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications', [NotificationController::class, 'store']);
    Route::match(['patch', 'post'], '/notifications/{id}/read', [NotificationController::class, 'markRead']);
    Route::post('/notifications/mark-read', [NotificationController::class, 'markRead']);

    // الخدمات وأنواع الرعاية
    Route::get('/services', [ServiceController::class, 'getServices']);
    Route::post('/services/request', [ServiceController::class, 'requestService']);
    Route::get('/services/requests', [ServiceController::class, 'getServiceRequests']);
    Route::get('/type-of-care', [ServiceController::class, 'getTypeOfCare']);
    Route::post('/type-of-care', [ServiceController::class, 'storeTypeOfCare']);

    // الذكاء الاصطناعي
    Route::post('/ai/voice-assistant', [AiVoiceAssistantController::class, 'ask']);
    Route::post('/voice-assistant/ask', [AiVoiceAssistantController::class, 'ask']);
});

// 14. طبقة التوافق الشاملة (Legacy Bridge) — same AuthZ via legacy.auth
Route::match(['get', 'post'], '/legacy', [LegacyBridgeController::class, 'handle'])
    ->middleware('legacy.auth');
Route::match(['get', 'post'], '/bridge', [LegacyBridgeController::class, 'handle'])
    ->middleware('legacy.auth');
