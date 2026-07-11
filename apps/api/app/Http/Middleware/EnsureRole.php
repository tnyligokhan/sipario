<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Rol tabanlı yetki: route'a `role:patron,operator` gibi verilir.
 * Kullanıcının rolü izinli listede değilse 403. auth:sanctum'dan SONRA çalışmalıdır.
 */
class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if ($user === null) {
            abort(401);
        }

        // role bir UserRole enum'una cast edilir; string değerini karşılaştır.
        $current = $user->role instanceof \BackedEnum ? $user->role->value : $user->role;

        if (! in_array($current, $roles, true)) {
            abort(403, 'Bu işlem için yetkiniz yok.');
        }

        return $next($request);
    }
}
