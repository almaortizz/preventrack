<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;

abstract class Controller
{
    // Tamaño de página de las listas: 20 por defecto (panel), hasta 100 si se
    // pide con per_page (la app recorre todas las páginas)
    protected function porPagina(Request $request): int
    {
        return min(max((int) $request->input('per_page', 20), 1), 100);
    }

    // Momento real de una acción hecha en la app. Si se hizo sin conexión,
    // la petición llega después (al sincronizar), así que se usa la hora que
    // manda el celular; si no viene, no es válida o está en el futuro, la actual.
    protected function momentoRegistro(?string $valor): Carbon
    {
        $ahora = now();
        if (!$valor) {
            return $ahora;
        }

        try {
            $momento = Carbon::parse($valor)->setTimezone(config('app.timezone'));
        } catch (\Throwable) {
            return $ahora;
        }

        return $momento->greaterThan($ahora) ? $ahora : $momento;
    }
}
