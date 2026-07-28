<?php

namespace App\Http\Controllers;

use App\Models\Cotizacion;
use App\Models\Producto;
use App\Models\Venta;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CotizacionController extends Controller
{
    public function index(Request $request)
    {
        $query = Cotizacion::with(['domicilio.cliente', 'usuario']);

        if ($request->filled('estado')) {
            $query->where('estado', $request->estado);
        }

        return response()->json(
            $query->orderByDesc('fecha_hora')->paginate(20)
        );
    }

    public function store(Request $request)
    {
        $datos = $request->validate([
            'domicilio_id' => 'required|exists:domicilios,id',
            'usuario_id' => 'required|exists:usuarios,id',
            'productos' => 'required|array|min:1',
            'productos.*.producto_id' => 'required|exists:productos,id',
            'productos.*.cantidad' => 'required|integer|min:1',
        ]);

        $cotizacion = DB::transaction(function () use ($datos) {

            $total = 0;
            $detalles = [];

            foreach ($datos['productos'] as $item) {
                $producto = Producto::findOrFail($item['producto_id']);
                $subtotal = $producto->precio_venta * $item['cantidad'];
                $total += $subtotal;

                $detalles[] = [
                    'producto_id' => $producto->id,
                    'cantidad' => $item['cantidad'],
                    'precio_unitario' => $producto->precio_venta,
                    'subtotal' => $subtotal,
                ];
            }

            $cotizacion = Cotizacion::create([
                'folio' => 'COT-' . strtoupper(uniqid()),
                'domicilio_id' => $datos['domicilio_id'],
                'usuario_id' => $datos['usuario_id'],
                'fecha_hora' => now(),
                'total' => $total,
                'estado' => 'cotizada',
            ]);

            $cotizacion->detalle()->createMany($detalles);

            return $cotizacion;
        });

        return response()->json($cotizacion->load('detalle.producto'), 201);
    }

    public function show(Cotizacion $cotizacion)
    {
        return response()->json(
            $cotizacion->load(['domicilio.cliente', 'usuario', 'detalle.producto'])
        );
    }

    public function update(Request $request, Cotizacion $cotizacion)
    {
        if ($cotizacion->estado !== 'cotizada') {
            throw ValidationException::withMessages([
                'estado' => ['Solo se puede editar una cotización que sigue en estado "cotizada".'],
            ]);
        }

        $datos = $request->validate([
            'domicilio_id' => 'sometimes|exists:domicilios,id',
        ]);

        $cotizacion->update($datos);

        return response()->json($cotizacion);
    }

    // Convierte la cotización en un pedido real (Venta)
    public function convertir(Cotizacion $cotizacion)
    {
        if ($cotizacion->estado !== 'cotizada') {
            throw ValidationException::withMessages([
                'estado' => ['Esta cotización ya fue convertida o cancelada.'],
            ]);
        }

        $venta = DB::transaction(function () use ($cotizacion) {

            $venta = Venta::create([
                'numero_orden' => 'PED-' . strtoupper(uniqid()),
                'domicilio_id' => $cotizacion->domicilio_id,
                'preventista_vendedor_id' => $cotizacion->usuario_id,
                'fecha_hora' => now(),
                'total' => $cotizacion->total,
                'estado' => 'pendiente',
            ]);

            foreach ($cotizacion->detalle as $item) {
                $venta->detalle()->create([
                    'producto_id' => $item->producto_id,
                    'cantidad' => $item->cantidad,
                    'precio_unitario' => $item->precio_unitario,
                    'subtotal' => $item->subtotal,
                ]);
            }

            $cotizacion->update([
                'estado' => 'convertida',
                'venta_id' => $venta->id,
            ]);

            return $venta;
        });

        return response()->json($venta->load('detalle.producto'), 201);
    }

    public function destroy(Cotizacion $cotizacion)
    {
        $cotizacion->update(['estado' => 'cancelada']);

        return response()->json(['message' => 'Cotización cancelada correctamente.']);
    }
}
