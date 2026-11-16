<?php
/**
 * Yusr API - Laravel Unified Gateway
 * بوابة مشروع يُسر الموحدة - تُشغّل وتُحوّل كافة الطلبات إلى Laravel 10 API
 */

if (!headers_sent()) {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, Origin');
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(200);
    exit;
}

define('LARAVEL_START', microtime(true));

$possiblePaths = [
    __DIR__ . '/backend',
    __DIR__ . '/../../Desktop/Yusr-project/Yusr-MobileApp/yusr1/backend',
    'C:/Users/leader/Desktop/Yusr-project/Yusr-MobileApp/yusr1/backend'
];

$laravelPath = null;
foreach ($possiblePaths as $path) {
    if (file_exists($path . '/vendor/autoload.php')) {
        $laravelPath = $path;
        break;
    }
}

if (!$laravelPath) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'status' => 'error',
        'message' => 'تعذر العثور على مجلد مشروع Laravel الخلفي'
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

require_once $laravelPath . '/vendor/autoload.php';
$app = require_once $laravelPath . '/bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);

$request = Illuminate\Http\Request::capture();

// توجيه الطلبات الواردة التي لا تحدد مسار API مسبقاً إلى مسار Legacy Bridge
$pathInfo = $request->getPathInfo();
if ($pathInfo === '' || $pathInfo === '/' || str_contains($pathInfo, 'index.php') || !str_contains($pathInfo, '/api/')) {
    $queryString = $request->getQueryString();
    $request = $request->duplicate(null, null, null, null, null, array_merge($request->server->all(), [
        'REQUEST_URI' => '/api/legacy' . ($queryString ? '?' . $queryString : ''),
        'PATH_INFO' => '/api/legacy',
    ]));
}

$response = $kernel->handle($request);
$response->send();
$kernel->terminate($request, $response);
