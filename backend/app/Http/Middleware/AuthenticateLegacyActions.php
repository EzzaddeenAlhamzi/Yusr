<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Auth\Middleware\Authenticate as AuthenticateMiddleware;
use Illuminate\Http\Request;

/**
 * Legacy/bridge dispatcher: keep ping + auth public; require Sanctum for everything else.
 */
class AuthenticateLegacyActions
{
    public const PUBLIC_ACTIONS = [
        'ping',
        'register_caregiver',
        'login_caregiver',
        'register_elderly',
        'login_elderly',
        'forgot_password',
    ];

    public function handle(Request $request, Closure $next)
    {
        $action = $request->input('action', $request->query('action', 'ping'));

        if (in_array($action, self::PUBLIC_ACTIONS, true)) {
            return $next($request);
        }

        return app(AuthenticateMiddleware::class)->handle(
            $request,
            $next,
            'sanctum'
        );
    }
}
