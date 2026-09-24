<?php

namespace App\Http\Controllers;

use App\Models\Jornada;
use App\Models\Ruta;
use App\Models\Usuario;
use Carbon\Carbon;

class MonitoreoController extends Controller
{
    public function index()
    {
        $hoy = Carbon::now('America/Mexico_City')->toDateString();

        $preventistas = Usuario::where('rol_id', 2)
            ->where('estado', 'activo')
            ->orderBy('nombre')
            ->get();

        $resultado = $preventistas->map(function ($p) use ($hoy) {
            $jornada = Jornada::where('usuario_id', $p->id)
                ->whereDate('fecha', $hoy)
                ->first();

            $jornadaActiva = $jornada && $jornada->hora_inicio && !$jornada->hora_fin;

            $ruta = Ruta::with('detalle')
                ->where('usuario_id', $p->id)
                ->where('fecha', $hoy)
                ->first();

            $totalParadas = $ruta ? $ruta->detalle->count() : 0;
            $paradasVisitadas = $ruta ? $ruta->detalle->where('estado', 'visitada')->count() : 0;

            // Prioridad: ubicación en vivo reportada por la app (más precisa y
            // reciente) sobre la ubicación capturada al iniciar la jornada.
            $ubicacion = null;
            if ($p->ultima_latitud && $p->ultima_longitud) {
                $minutosDesdeUltimoReporte = $p->ultima_ubicacion_at
                    ? Carbon::parse($p->ultima_ubicacion_at)->diffInMinutes(now())
                    : null;

                $ubicacion = [
                    'latitud' => $p->ultima_latitud,
                    'longitud' => $p->ultima_longitud,
                    'origen' => 'en_vivo',
                    'actualizada' => $p->ultima_ubicacion_at,
                    'reciente' => $minutosDesdeUltimoReporte !== null && $minutosDesdeUltimoReporte <= 10,
                ];
            } elseif ($jornada && $jornada->latitud_inicio && $jornada->longitud_inicio) {
                $ubicacion = [
                    'latitud' => $jornada->latitud_inicio,
                    'longitud' => $jornada->longitud_inicio,
                    'origen' => 'inicio_jornada',
                    'reciente' => false,
                ];
            }

            return [
                'id' => $p->id,
                'nombre' => $p->nombre . ' ' . $p->apellidos,
                'color' => $p->color,
                'jornada_activa' => $jornadaActiva,
                'hora_inicio' => $jornada->hora_inicio ?? null,
                'ubicacion' => $ubicacion,
                'ruta' => [
                    'tiene_ruta_hoy' => (bool) $ruta,
                    'total_paradas' => $totalParadas,
                    'paradas_visitadas' => $paradasVisitadas,
                    'estado' => $ruta->estado ?? null,
                ],
            ];
        });

        return response()->json($resultado);
    }
}
