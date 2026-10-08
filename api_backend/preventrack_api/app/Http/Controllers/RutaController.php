<?php

namespace App\Http\Controllers;

use App\Models\RegistroGps;
use App\Models\Ruta;
use App\Models\Visita;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

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
            'paradas' => 'required|array|min:1',
            'paradas.*.domicilio_id' => 'required|exists:domicilios,id',
            'paradas.*.venta_id' => 'nullable|exists:ventas,id',
        ]);

        $ruta = Ruta::create([
            'usuario_id' => $datos['usuario_id'],
            'fecha' => $datos['fecha'],
            'estado' => 'planeada',
        ]);

        foreach ($datos['paradas'] as $orden => $parada) {
            $ruta->detalle()->create([
                'domicilio_id' => $parada['domicilio_id'],
                'venta_id' => $parada['venta_id'] ?? null,
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

    // Registra la visita a una parada sin pedido: "sin_venta" la deja visitada,
    // "no_disponible" permite volver a atenderla ese mismo día.
    // La entrega de pedidos se registra aparte (ventas/{venta}/marcar-entregado).
    public function marcarVisitada(Request $request, Ruta $ruta, $detalleRutaId)
    {
        $datos = $request->validate([
            'resultado' => 'required|in:sin_venta,no_disponible',
            'latitud'   => 'nullable|numeric|between:-90,90',
            'longitud'  => 'nullable|numeric|between:-180,180',
            'precision' => 'nullable|numeric|min:0',
        ]);

        if (!$ruta->puedeAtender($request->user())) {
            return response()->json(['message' => 'Esta ruta no está asignada a tu usuario.'], 403);
        }

        $detalle = $ruta->detalle()->with('domicilio')->findOrFail($detalleRutaId);

        if ($detalle->estado === 'visitada') {
            throw ValidationException::withMessages([
                'estado' => ['Esta parada ya fue visitada.'],
            ]);
        }

        DB::transaction(function () use ($request, $datos, $ruta, $detalle) {
            $lat = $datos['latitud'] ?? null;
            $lng = $datos['longitud'] ?? null;

            Visita::create([
                'usuario_id'   => $request->user()->id,
                'domicilio_id' => $detalle->domicilio_id,
                'fecha_hora'   => now(),
                'latitud'      => $lat,
                'longitud'     => $lng,
                'precision_m'  => $datos['precision'] ?? null,
                'distancia_m'  => RegistroGps::distanciaMetros($lat, $lng, $detalle->domicilio),
                'resultado'    => $datos['resultado'],
            ]);

            $detalle->update([
                'estado' => $datos['resultado'] === 'no_disponible' ? 'no_disponible' : 'visitada',
            ]);

            $ruta->actualizarEstado();
        });

        return response()->json($ruta->load('detalle.domicilio.cliente', 'detalle.venta'));
    }

    public function destroy(Ruta $ruta)
    {
        $ruta->delete();

        return response()->json(['message' => 'Ruta eliminada correctamente.']);
    }
}
