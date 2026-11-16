<?php

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);

function callApi($kernel, $method, $uri, $params = []) {
    $req = Illuminate\Http\Request::create($uri, $method, $params, [], [], [
        'CONTENT_TYPE' => 'application/json',
        'HTTP_ACCEPT' => 'application/json',
    ], json_encode($params));

    $res = $kernel->handle($req);
    $content = $res->getContent();
    $kernel->terminate($req, $res);
    return json_decode($content, true) ?? $content;
}

echo "=== 1. TEST PING ===\n";
print_r(callApi($kernel, 'GET', '/api/ping'));

echo "\n=== 2. TEST GET CAREGIVER (ID=1) ===\n";
print_r(callApi($kernel, 'GET', '/api/caregiver/1'));

echo "\n=== 3. TEST GET ELDERLY (ID=1) ===\n";
print_r(callApi($kernel, 'GET', '/api/elderly/1'));

echo "\n=== 4. TEST LEGACY BRIDGE (action=get_caregiver) ===\n";
print_r(callApi($kernel, 'POST', '/api/legacy', ['action' => 'get_caregiver', 'Caregivers_ID' => 1]));

echo "\n=== 5. TEST GET SERVICES ===\n";
print_r(callApi($kernel, 'GET', '/api/services'));

echo "\n=== 6. TEST GET EMERGENCY LOGS ===\n";
print_r(callApi($kernel, 'GET', '/api/emergency/logs'));

echo "\n=== 7. TEST AI VOICE ASSISTANT (no key set yet) ===\n";
print_r(callApi($kernel, 'POST', '/api/ai/voice-assistant', ['elderly_id' => 1, 'prompt' => 'ما هي أدويتي؟']));
