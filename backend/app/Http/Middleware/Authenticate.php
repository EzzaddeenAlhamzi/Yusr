<?php

namespace App\Http\Middleware;

use Illuminate\Auth\Middleware\Authenticate as Middleware;
use Illuminate\Http\Request;

class Authenticate extends Middleware
{
    /**
     * API / legacy clients must never be redirected to a web login route.
     */
    protected function redirectTo(Request $request): ?string
    {
        return null;
    }
}
