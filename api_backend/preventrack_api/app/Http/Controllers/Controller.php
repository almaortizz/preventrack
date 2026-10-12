<?php

namespace App\Http\Controllers;

use Carbon\Carbon;

abstract class Controller
{
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
