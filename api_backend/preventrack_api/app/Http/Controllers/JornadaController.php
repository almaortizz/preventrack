<?php

namespace App\Http\Controllers;

use App\Models\Jornada;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class JornadaController extends Controller
{
    public function index(Request $request)
    {
        $query = Jornada::with('usuario');

        if ($request->filled('usuario_id')) {
            $query->where('usuario_id', $request->usuario_id);
        }

        if ($request->filled('fecha')) {
            $query->whereDate('fecha', $request->fecha);
        }

        return response()->json($query->orderByDesc('fecha')->paginate(20));
    }

    // Iniciar jornada (hora + ubicación)
    public function iniciar(Request $request)
    {
        $datos = $request->validate([
            'usuario_id' => 'required|exists:usuarios,id',
            'latitud_inicio' => 'nullable|numeric',
            'longitud_inicio' => 'nullable|numeric',
        ]);

        $jornadaAbierta = Jornada::where('usuario_id', $datos['usuario_id'])
            ->whereNull('hora_fin')
            ->first();

        if ($jornadaAbierta) {
            throw ValidationException::withMessages([
                'jornada' => ['Este colaborador ya tiene una jornada abierta. Debe finalizarla antes de iniciar otra.'],
            ]);
        }

        $jornada = Jornada::create([
            'usuario_id' => $datos['usuario_id'],
            'fecha' => now()->toDateString(),
            'hora_inicio' => now(),
            'latitud_inicio' => $datos['latitud_inicio'] ?? null,
            'longitud_inicio' => $datos['longitud_inicio'] ?? null,
        ]);

        return response()->json($jornada, 201);
    }

    // Marcar inicio de comida
    public function iniciarComida(Jornada $jornada)
    {
        if ($jornada->hora_fin) {
            throw ValidationException::withMessages([
                'jornada' => ['Esta jornada ya fue finalizada.'],
            ]);
        }

        if ($jornada->hora_inicio_comida) {
            throw ValidationException::withMessages([
                'jornada' => ['Ya se registró el inicio de la comida para esta jornada.'],
            ]);
        }

        $jornada->update(['hora_inicio_comida' => now()]);

        return response()->json($jornada);
    }

    // Marcar fin de comida
    public function finalizarComida(Jornada $jornada)
    {
        if (! $jornada->hora_inicio_comida) {
            throw ValidationException::withMessages([
                'jornada' => ['Primero debe registrarse el inicio de la comida.'],
            ]);
        }

        if ($jornada->hora_fin_comida) {
            throw ValidationException::withMessages([
                'jornada' => ['Ya se registró el fin de la comida para esta jornada.'],
            ]);
        }

        $jornada->update(['hora_fin_comida' => now()]);

        return response()->json($jornada);
    }

    // Finalizar jornada (hora + ubicación)
    public function finalizar(Request $request, Jornada $jornada)
    {
        $datos = $request->validate([
            'latitud_fin' => 'nullable|numeric',
            'longitud_fin' => 'nullable|numeric',
        ]);

        if ($jornada->hora_fin) {
            throw ValidationException::withMessages([
                'jornada' => ['Esta jornada ya fue finalizada anteriormente.'],
            ]);
        }

        $jornada->update([
            'hora_fin' => now(),
            'latitud_fin' => $datos['latitud_fin'] ?? null,
            'longitud_fin' => $datos['longitud_fin'] ?? null,
        ]);

        return response()->json($jornada);
    }

    public function show(Jornada $jornada)
    {
        return response()->json($jornada->load('usuario'));
    }
}
