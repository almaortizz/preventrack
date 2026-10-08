<?php

namespace App\Http\Controllers;

use App\Models\DetalleRuta;
use App\Models\Producto;
use App\Models\RegistroGps;
use App\Models\Ruta;
use App\Models\Venta;
use App\Models\Visita;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class VentaController extends Controller
{
    public function index(Request $request)
    {
        $query = Venta::with(['domicilio.cliente', 'vendedor', 'repartidor', 'detalle.producto']);

        if ($request->filled('estado')) {
            $query->where('estado', $request->estado);
        }

        if ($request->filled('preventista_vendedor_id')) {
            $query->where('preventista_vendedor_id', $request->preventista_vendedor_id);
        }

        if ($request->filled('cliente_id')) {
            $query->whereHas('domicilio', function ($q) use ($request) {
                $q->where('cliente_id', $request->cliente_id);
            });
        }


        if ($request->filled('preventista_entrega_id')) {
            $query->where('preventista_entrega_id', $request->preventista_entrega_id);
        }

        if ($request->filled('fecha_inicio')) {
            $query->whereDate('fecha_hora', '>=', $request->fecha_inicio);
        }

        if ($request->filled('fecha_fin')) {
            $query->whereDate('fecha_hora', '<=', $request->fecha_fin);
        }

               $porPagina = $request->input('per_page', 20);

        return response()->json(
            $query->orderByDesc('fecha_hora')->paginate($porPagina)
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
            'descuento' => 'nullable|numeric|min:0',
            'fecha_inicio_creacion' => 'nullable|date',
            'fecha_fin_creacion' => 'nullable|date',
            'productos' => 'required|array|min:1',
            'productos.*.producto_id' => 'required|exists:productos,id',
            'productos.*.cantidad' => 'required|integer|min:1',
            'detalle_ruta_id' => 'nullable|integer',
            'precision' => 'nullable|numeric|min:0',
        ]);

        $venta = DB::transaction(function () use ($request, $datos) {

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

            $descuento = $datos['descuento'] ?? 0;
            $totalFinal = $total - $descuento;
            if ($totalFinal < 0) $totalFinal = 0;

            $venta = Venta::create([
                'numero_orden' => 'PED-' . strtoupper(uniqid()),
                'domicilio_id' => $datos['domicilio_id'],
                'preventista_vendedor_id' => $datos['preventista_vendedor_id'],
                'fecha_hora' => now(),
                'total' => $totalFinal,
                'descuento' => $descuento,
                'estado' => 'pendiente',
                'latitud_registro' => $datos['latitud_registro'] ?? null,
                'longitud_registro' => $datos['longitud_registro'] ?? null,
                'notas' => $datos['notas'] ?? null,
                'fecha_inicio_creacion' => $datos['fecha_inicio_creacion'] ?? null,
                'fecha_fin_creacion' => $datos['fecha_fin_creacion'] ?? null,
            ]);

            $venta->detalle()->createMany($detalles);

            $this->registrarVisitaEnRuta($request, $venta, $datos);

            return $venta;
        });

        return response()->json($venta->load('detalle.producto'), 201);
    }

    // Si el domicilio del pedido es una parada sin atender de la ruta del
    // preventista, la marca visitada y registra la visita con resultado "venta".
    // Usa la parada indicada por la app (detalle_ruta_id) o, si no viene,
    // la busca en la ruta de hoy. Nunca impide que se cree el pedido.
    private function registrarVisitaEnRuta(Request $request, Venta $venta, array $datos): void
    {
        $sinAtender = ['pendiente', 'no_disponible'];
        $detalleRutaId = $datos['detalle_ruta_id'] ?? null;

        if ($detalleRutaId) {
            $detalle = DetalleRuta::with(['ruta', 'domicilio'])
                ->where('id', $detalleRutaId)
                ->where('domicilio_id', $venta->domicilio_id)
                ->whereIn('estado', $sinAtender)
                ->first();
        } else {
            $hoy = Carbon::now('America/Mexico_City')->toDateString();
            $ruta = Ruta::where('usuario_id', $venta->preventista_vendedor_id)
                ->whereDate('fecha', $hoy)
                ->first();

            $detalle = $ruta?->detalle()
                ->with(['ruta', 'domicilio'])
                ->where('domicilio_id', $venta->domicilio_id)
                ->whereIn('estado', $sinAtender)
                ->orderBy('orden_visita')
                ->first();
        }

        if (!$detalle
            || (int) $detalle->ruta->usuario_id !== (int) $venta->preventista_vendedor_id
            || !$detalle->ruta->puedeAtender($request->user())) {
            return;
        }

        $lat = $venta->latitud_registro;
        $lng = $venta->longitud_registro;

        Visita::create([
            'usuario_id'   => $venta->preventista_vendedor_id,
            'domicilio_id' => $venta->domicilio_id,
            'fecha_hora'   => now(),
            'latitud'      => $lat,
            'longitud'     => $lng,
            'precision_m'  => $datos['precision'] ?? null,
            'distancia_m'  => RegistroGps::distanciaMetros($lat, $lng, $detalle->domicilio),
            'resultado'    => 'venta',
            'venta_id'     => $venta->id,
        ]);

        $detalle->update(['estado' => 'visitada']);
        $detalle->ruta->actualizarEstado();
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
    public function marcarEntregado(Request $request, Venta $venta)
    {
        $request->validate([
            'latitud'   => 'nullable|numeric|between:-90,90',
            'longitud'  => 'nullable|numeric|between:-180,180',
            'precision' => 'nullable|numeric|min:0',
        ]);

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

        // Guardar dónde estaba el preventista al entregar
        RegistroGps::desdeRequest($request, 'entrega', $venta->domicilio, [
            'venta_id' => $venta->id,
        ]);

        return response()->json($venta);
    }

    // El cliente no recibió el pedido: regresa a "pendiente" para reprogramar
    public function marcarNoEntregado(Request $request, Venta $venta)
    {
        $request->validate([
            'latitud'   => 'nullable|numeric|between:-90,90',
            'longitud'  => 'nullable|numeric|between:-180,180',
            'precision' => 'nullable|numeric|min:0',
        ]);

        if ($venta->estado !== 'en_ruta') {
            throw ValidationException::withMessages([
                'estado' => ['Solo un pedido en ruta puede regresar a pendiente.'],
            ]);
        }

        $venta->update(['estado' => 'pendiente']);

        // Guardar dónde estaba el preventista al reportar que no se entregó
        RegistroGps::desdeRequest($request, 'no_entregado', $venta->domicilio, [
            'venta_id' => $venta->id,
        ]);

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
