<?php

namespace App\Http\Controllers;

use App\Models\Producto;
use App\Models\Venta;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class VentaController extends Controller
{
    public function index(Request $request)
    {
        $query = Venta::with(['domicilio.cliente', 'vendedor', 'repartidor']);

        if ($request->filled('estado')) {
            $query->where('estado', $request->estado);
        }

        if ($request->filled('preventista_vendedor_id')) {
            $query->where('preventista_vendedor_id', $request->preventista_vendedor_id);
        }

        if ($request->filled('fecha')) {
            $query->whereDate('fecha_hora', $request->fecha);
        }

        return response()->json(
            $query->orderByDesc('fecha_hora')->paginate(20)
        );
    }

    // Registrar un pedido nuevo (siempre nace en estado "pendiente")
    public function store(Request $request)
    {
        $datos = $request->validate([
            'domicilio_id' => 'required|exists:domicilios,id',
            'preventista_vendedor_id' => 'required|exists:usuarios,id',
            'latitud_registro' => 'nullable|numeric',
            'longitud_registro' => 'nullable|numeric',
            'notas' => 'nullable|string',
            'productos' => 'required|array|min:1',
            'productos.*.producto_id' => 'required|exists:productos,id',
            'productos.*.cantidad' => 'required|integer|min:1',
        ]);

        $venta = DB::transaction(function () use ($datos) {

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

            $venta = Venta::create([
                'numero_orden' => 'PED-' . strtoupper(uniqid()),
                'domicilio_id' => $datos['domicilio_id'],
                'preventista_vendedor_id' => $datos['preventista_vendedor_id'],
                'fecha_hora' => now(),
                'total' => $total,
                'estado' => 'pendiente',
                'latitud_registro' => $datos['latitud_registro'] ?? null,
                'longitud_registro' => $datos['longitud_registro'] ?? null,
                'notas' => $datos['notas'] ?? null,
            ]);

            $venta->detalle()->createMany($detalles);

            return $venta;
        });

        return response()->json($venta->load('detalle.producto'), 201);
    }

    public function show(Venta $venta)
    {
        return response()->json(
            $venta->load(['domicilio.cliente', 'vendedor', 'repartidor', 'detalle.producto'])
        );
    }

    // Editar datos generales del pedido (solo antes de imprimir el ticket)
    public function update(Request $request, Venta $venta)
    {
        if ($venta->impreso) {
            throw ValidationException::withMessages([
                'venta' => ['Este pedido ya no se puede modificar porque el ticket ya fue impreso.'],
            ]);
        }

        $datos = $request->validate([
            'domicilio_id' => 'sometimes|exists:domicilios,id',
            'notas' => 'nullable|string',
        ]);

        $venta->update($datos);

        return response()->json($venta);
    }

    // Asignar el colaborador que hará la entrega (pendiente -> en_ruta)
    public function asignarEntrega(Request $request, Venta $venta)
    {
        $datos = $request->validate([
            'preventista_entrega_id' => 'required|exists:usuarios,id',
        ]);

        if ($venta->estado !== 'pendiente') {
            throw ValidationException::withMessages([
                'estado' => ['Solo se puede asignar entrega a un pedido pendiente.'],
            ]);
        }

        $venta->update([
            'preventista_entrega_id' => $datos['preventista_entrega_id'],
            'estado' => 'en_ruta',
        ]);

        return response()->json($venta);
    }

    // Marcar el pedido como entregado (en_ruta -> entregado)
    public function marcarEntregado(Venta $venta)
    {
        if ($venta->estado !== 'en_ruta') {
            throw ValidationException::withMessages([
                'estado' => ['Solo se puede entregar un pedido que está en ruta.'],
            ]);
        }

        $venta->update([
            'estado' => 'entregado',
            'fecha_entrega' => now()->toDateString(),
            'hora_entrega' => now()->toTimeString(),
        ]);

        return response()->json($venta);
    }

    // El cliente no recibió el pedido: regresa a "pendiente" para reprogramar
    public function marcarNoEntregado(Venta $venta)
    {
        if ($venta->estado !== 'en_ruta') {
            throw ValidationException::withMessages([
                'estado' => ['Solo un pedido en ruta puede regresar a pendiente.'],
            ]);
        }

        $venta->update(['estado' => 'pendiente']);

        return response()->json($venta);
    }

    // Cancelar el pedido (solo si aún no ha sido entregado)
    public function cancelar(Request $request, Venta $venta)
    {
        $datos = $request->validate([
            'motivo_cancelacion' => 'nullable|string|max:255',
        ]);

        if ($venta->estado === 'entregado') {
            throw ValidationException::withMessages([
                'estado' => ['No se puede cancelar un pedido que ya fue entregado.'],
            ]);
        }

        $venta->update([
            'estado' => 'cancelado',
            'motivo_cancelacion' => $datos['motivo_cancelacion'] ?? null,
        ]);

        return response()->json($venta);
    }

    // Marcar que el ticket ya se imprimió (bloquea futuras ediciones)
    public function marcarImpreso(Venta $venta)
    {
        $venta->update([
            'impreso' => true,
            'fecha_impresion' => now(),
        ]);

        return response()->json($venta);
    }

    public function destroy(Venta $venta)
    {
        $venta->delete();

        return response()->json(['message' => 'Pedido eliminado correctamente.']);
    }
}
