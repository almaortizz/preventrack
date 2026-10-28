<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

// Rutas de administración (panel web): solo el administrador (rol_id = 1).
// El preventista solo usa las rutas que necesita la app.
class SoloAdministrador
{
    public function handle(Request $request, Closure $next): Response
    {
        if ((int) $request->user()?->rol_id !== 1) {
            return response()->json(['message' => 'No autorizado'], 403);
        }

        return $next($request);
    }
}
