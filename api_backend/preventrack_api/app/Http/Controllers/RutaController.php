<?php

namespace App\Http\Controllers;

use App\Models\Ruta;
use App\Models\Venta;
use Illuminate\Http\Request;

class RutaController extends Controller
{
    public function index(Request $request)
    {
        $query = Ruta::with(['usuario', 'detalle.domicilio.cliente', 'detalle.venta']);

        if ($request->filled('usuario_id')) {
            $query->where('usuario_id', $request->usuario_id);
        }

        if ($request->filled('fecha')) {
            $query->whereDate('fecha', $request->fecha);
        }

        return response()->json($query->orderByDesc('fecha')->paginate(20));
    }

    // Arma la ruta completa a partir de pedidos ya asignados para entrega
    public function store(Request $request)
    {
        $datos = $request->validate([
            'usuario_id' => 'required|exists:usuarios,id',
            'fecha' => 'required|date',
            'ventas' => 'required|array|min:1',
            'ventas.*' => 'required|exists:ventas,id',
        ]);

        $ruta = Ruta::create([
            'usuario_id' => $datos['usuario_id'],
            'fecha' => $datos['fecha'],
            'estado' => 'planeada',
        ]);

        foreach ($datos['ventas'] as $orden => $ventaId) {
            $venta = Venta::find($ventaId);
            if (!$venta) {
                continue;
            }

            $ruta->detalle()->create([
                'domicilio_id' => $venta->domicilio_id,
                'venta_id' => $venta->id,
                'orden_visita' => $orden + 1,
                'estado' => 'pendiente',
            ]);
        }

        return response()->json($ruta->load('detalle.domicilio.cliente', 'detalle.venta'), 201);
    }

    public function show(Ruta $ruta)
    {
        return response()->json($ruta->load(['usuario', 'detalle.domicilio.cliente', 'detalle.venta']));
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

        return response()->json($ruta->load('detalle.domicilio.cliente', 'detalle.venta'));
    }

    // Marca un domicilio de la ruta como visitado y, si tiene un pedido ligado,
    // lo marca automáticamente como entregado
    public function marcarVisitada(Ruta $ruta, $detalleRutaId)
    {
        $detalle = $ruta->detalle()->findOrFail($detalleRutaId);
        $detalle->update(['estado' => 'visitada']);

        if ($detalle->venta_id) {
            $venta = Venta::find($detalle->venta_id);
            if ($venta && $venta->estado === 'en_ruta') {
                $venta->update([
                    'estado' => 'entregado',
                    'fecha_entrega' => now()->toDateString(),
                    'hora_entrega' => now()->toTimeString(),
                ]);
            }
        }

        // Si ya no quedan pendientes, la ruta se marca finalizada
        $pendientes = $ruta->detalle()->where('estado', 'pendiente')->count();
        if ($pendientes === 0) {
            $ruta->update(['estado' => 'finalizada']);
        } elseif ($ruta->estado === 'planeada') {
            $ruta->update(['estado' => 'en_curso']);
        }

        return response()->json($ruta->load('detalle.domicilio.cliente', 'detalle.venta'));
    }

    public function destroy(Ruta $ruta)
    {
        $ruta->delete();

        return response()->json(['message' => 'Ruta eliminada correctamente.']);
    }
}
