<?php

namespace App\Http\Controllers;

use App\Models\Ruta;
use Illuminate\Http\Request;

class RutaController extends Controller
{
    public function index(Request $request)
    {
        $query = Ruta::with(['usuario', 'detalle.domicilio.cliente']);

        if ($request->filled('usuario_id')) {
            $query->where('usuario_id', $request->usuario_id);
        }

        if ($request->filled('fecha')) {
            $query->whereDate('fecha', $request->fecha);
        }

        return response()->json($query->orderByDesc('fecha')->paginate(20));
    }

    // Arma la ruta completa: crea la ruta y el orden de visitas de un jalón
    public function store(Request $request)
    {
        $datos = $request->validate([
            'usuario_id' => 'required|exists:usuarios,id',
            'fecha' => 'required|date',
            'domicilios' => 'required|array|min:1',
            'domicilios.*' => 'required|exists:domicilios,id',
        ]);

        $ruta = Ruta::create([
            'usuario_id' => $datos['usuario_id'],
            'fecha' => $datos['fecha'],
            'estado' => 'planeada',
        ]);

        foreach ($datos['domicilios'] as $orden => $domicilioId) {
            $ruta->detalle()->create([
                'domicilio_id' => $domicilioId,
                'orden_visita' => $orden + 1,
                'estado' => 'pendiente',
            ]);
        }

        return response()->json($ruta->load('detalle.domicilio.cliente'), 201);
    }

    public function show(Ruta $ruta)
    {
        return response()->json($ruta->load(['usuario', 'detalle.domicilio.cliente']));
    }

    // Permite al colaborador reordenar sus paradas
    public function reordenar(Request $request, Ruta $ruta)
    {
        $datos = $request->validate([
            'orden' => 'required|array|min:1',
            'orden.*.detalle_ruta_id' => 'required|exists:detalle_rutas,id',
            'orden.*.orden_visita' => 'required|integer|min:1',
        ]);

        foreach ($datos['orden'] as $item) {
            $ruta->detalle()
                ->where('id', $item['detalle_ruta_id'])
                ->update(['orden_visita' => $item['orden_visita']]);
        }

        return response()->json($ruta->load('detalle.domicilio.cliente'));
    }

    // Marca un domicilio de la ruta como visitado
    public function marcarVisitada(Ruta $ruta, $detalleRutaId)
    {
        $detalle = $ruta->detalle()->findOrFail($detalleRutaId);
        $detalle->update(['estado' => 'visitada']);

        // Si ya no quedan pendientes, la ruta se marca finalizada
        $pendientes = $ruta->detalle()->where('estado', 'pendiente')->count();
        if ($pendientes === 0) {
            $ruta->update(['estado' => 'finalizada']);
        } elseif ($ruta->estado === 'planeada') {
            $ruta->update(['estado' => 'en_curso']);
        }

        return response()->json($ruta->load('detalle.domicilio.cliente'));
    }

    public function destroy(Ruta $ruta)
    {
        $ruta->delete();

        return response()->json(['message' => 'Ruta eliminada correctamente.']);
    }
}
