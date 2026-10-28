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

        // Un preventista solo ve sus propias jornadas
        if ((int) $request->user()->rol_id !== 1) {
            $query->where('usuario_id', $request->user()->id);
        } elseif ($request->filled('usuario_id')) {
            $query->where('usuario_id', $request->usuario_id);
        }

        if ($request->filled('fecha')) {
            $query->whereDate('fecha', $request->fecha);
        }

        return response()->json($query->orderByDesc('fecha')->paginate($this->porPagina($request)));
    }

    // Jornada abierta del usuario que inició sesión (null si no tiene)
    public function actual(Request $request)
    {
        $jornada = Jornada::where('usuario_id', $request->user()->id)
            ->whereNull('hora_fin')
            ->latest('id')
            ->first();

        return response()->json(['jornada' => $jornada]);
    }

    // Registra un momento de la jornada del usuario que inició sesión:
    // iniciar, iniciar_comida, finalizar_comida o finalizar. No necesita el
    // id de la jornada, así la app puede guardarlo sin conexión y enviarlo
    // después; se usa la hora real en que se registró en el celular.
    public function registrar(Request $request)
    {
        $datos = $request->validate([
            'evento' => 'required|in:iniciar,iniciar_comida,finalizar_comida,finalizar',
            'latitud' => 'nullable|numeric|between:-90,90',
            'longitud' => 'nullable|numeric|between:-180,180',
            'fecha_hora_registro' => 'nullable|date',
        ]);

        $usuarioId = $request->user()->id;
        $momento = $this->momentoRegistro($datos['fecha_hora_registro'] ?? null);
        $lat = $datos['latitud'] ?? null;
        $lng = $datos['longitud'] ?? null;

        $abierta = Jornada::where('usuario_id', $usuarioId)
            ->whereNull('hora_fin')
            ->latest('id')
            ->first();

        if ($datos['evento'] === 'iniciar') {
            if ($abierta) {
                throw ValidationException::withMessages([
                    'jornada' => ['Ya tienes una jornada abierta. Debes finalizarla antes de iniciar otra.'],
                ]);
            }

            $jornada = Jornada::create([
                'usuario_id' => $usuarioId,
                'fecha' => $momento->toDateString(),
                'hora_inicio' => $momento,
                'latitud_inicio' => $lat,
                'longitud_inicio' => $lng,
            ]);

            return response()->json($jornada, 201);
        }

        if (!$abierta) {
            throw ValidationException::withMessages([
                'jornada' => ['No tienes una jornada abierta.'],
            ]);
        }

        if ($datos['evento'] === 'iniciar_comida') {
            if ($abierta->hora_inicio_comida) {
                throw ValidationException::withMessages([
                    'jornada' => ['Ya se registró el inicio de la comida para esta jornada.'],
                ]);
            }
            $abierta->update(['hora_inicio_comida' => $momento]);
        } elseif ($datos['evento'] === 'finalizar_comida') {
            if (!$abierta->hora_inicio_comida) {
                throw ValidationException::withMessages([
                    'jornada' => ['Primero debe registrarse el inicio de la comida.'],
                ]);
            }
            if ($abierta->hora_fin_comida) {
                throw ValidationException::withMessages([
                    'jornada' => ['Ya se registró el fin de la comida para esta jornada.'],
                ]);
            }
            $abierta->update(['hora_fin_comida' => $momento]);
        } else {
            if ($abierta->hora_inicio_comida && !$abierta->hora_fin_comida) {
                throw ValidationException::withMessages([
                    'jornada' => ['Termina la comida antes de finalizar la jornada.'],
                ]);
            }
            $abierta->update([
                'hora_fin' => $momento,
                'latitud_fin' => $lat,
                'longitud_fin' => $lng,
            ]);
        }

        return response()->json($abierta);
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

    public function show(Request $request, Jornada $jornada)
    {
        // Un preventista solo ve sus propias jornadas
        if ((int) $request->user()->rol_id !== 1
            && (int) $jornada->usuario_id !== (int) $request->user()->id) {
            return response()->json(['message' => 'No autorizado'], 403);
        }

        return response()->json($jornada->load('usuario'));
    }
}
