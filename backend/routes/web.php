<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\LegacyBridgeController;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
*/

Route::match(['get', 'post', 'options'], '/', [LegacyBridgeController::class, 'handle']);
Route::match(['get', 'post', 'options'], '/index.php', [LegacyBridgeController::class, 'handle']);
Route::match(['get', 'post', 'options'], '/yusr_api/index.php', [LegacyBridgeController::class, 'handle']);
