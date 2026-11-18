<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\LegacyBridgeController;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
| Same legacy dispatcher as /api/legacy — P1.2 legacy.auth applies.
*/

Route::match(['get', 'post', 'options'], '/', [LegacyBridgeController::class, 'handle'])
    ->middleware('legacy.auth');
Route::match(['get', 'post', 'options'], '/index.php', [LegacyBridgeController::class, 'handle'])
    ->middleware('legacy.auth');
Route::match(['get', 'post', 'options'], '/yusr_api/index.php', [LegacyBridgeController::class, 'handle'])
    ->middleware('legacy.auth');
