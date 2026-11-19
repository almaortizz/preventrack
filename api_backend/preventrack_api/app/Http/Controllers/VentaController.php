<?php

namespace App\Http\Controllers;

use App\Models\Cuota;
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

        // Un preventista solo ve los pedidos que levantó o que le toca entregar
        if ((int) $request->user()->rol_id !== 1) {
            $userId = $request->user()->id;
            $query->where(function ($q) use ($userId) {
                $q->where('preventista_vendedor_id', $userId)
                    ->orWhere('preventista_entrega_id', $userId);
            });
        }

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

        $porPagina = $this->porPagina($request);

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
            // Folio generado en el celular: serie del preventista + año + consecutivo
            'numero_orden' => 'nullable|string|max:30',
            // Ticket impreso en el celular antes de sincronizar
            'impreso' => 'nullable|boolean',
        ]);

        $folio = $datos['numero_orden'] ?? null;
        if ($folio !== null) {
            $this->validarFolio($folio, (int) $datos['preventista_vendedor_id'], $request);

            $existente = Venta::where('numero_orden', $folio)->first();
            if ($existente) {
                // Reintento del mismo pedido (p. ej. la cola lo reenvió porque se
                // perdió la respuesta): mismo folio, preventista e inicio de captura
                if ($this->esMismoPedido($existente, $datos)) {
                    return response()->json($existente->load('detalle.producto'), 200);
                }

                throw ValidationException::withMessages([
                    'numero_orden' => ["El folio {$folio} ya está registrado en otro pedido."],
                ]);
            }
        }

        $venta = DB::transaction(function () use ($request, $datos, $folio) {

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

            $impreso = (bool) ($datos['impreso'] ?? false);

            $venta = Venta::create([
                // Sin folio de la app (panel o versiones anteriores de la app)
                // se genera como siempre, en otra serie que no choca
                'numero_orden' => $folio ?? 'PED-' . strtoupper(uniqid()),
                'impreso' => $impreso,
                'fecha_impresion' => $impreso ? now() : null,
                'domicilio_id' => $datos['domicilio_id'],
                'preventista_vendedor_id' => $datos['preventista_vendedor_id'],
                // Hora en que se terminó de levantar el pedido (si se hizo
                // sin conexión, llega después al sincronizar)
                'fecha_hora' => $this->momentoRegistro($datos['fecha_fin_creacion'] ?? null),
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
            'fecha_hora'   => $this->momentoRegistro($datos['fecha_fin_creacion'] ?? null),
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

    // Folio de la app: P{id del preventista}-{AA}-{consecutivo de 4 o más
    // dígitos}, p. ej. P2-26-0153. Solo se acepta la serie del propio
    // preventista que levanta el pedido.
    private function validarFolio(string $folio, int $vendedorId, Request $request): void
    {
        $valido = preg_match('/^P(\d+)-\d{2}-\d{4,}$/', $folio, $partes)
            && (int) $partes[1] === $vendedorId
            && (int) $request->user()->id === $vendedorId;

        if (!$valido) {
            throw ValidationException::withMessages([
                'numero_orden' => ["El folio {$folio} no es válido."],
            ]);
        }
    }

    // Un folio repetido solo es reintento si también coinciden el preventista
    // y el inicio de captura (al segundo); si no, es un conflicto
    private function esMismoPedido(Venta $existente, array $datos): bool
    {
        if ((int) $existente->preventista_vendedor_id !== (int) $datos['preventista_vendedor_id']) {
            return false;
        }

        $inicioNuevo = $datos['fecha_inicio_creacion'] ?? null;
        if (!$existente->fecha_inicio_creacion || !$inicioNuevo) {
            return false;
        }

        return $existente->fecha_inicio_creacion->format('Y-m-d H:i:s')
            === Carbon::parse($inicioNuevo)->format('Y-m-d H:i:s');
    }

    // Último consecutivo de la serie del usuario en un año (por defecto el
    // actual). La app lo usa para continuar su numeración aunque cambie de
    // celular o reinstale la app. Se compara como número (10000 > 9999).
    public function ultimoFolio(Request $request)
    {
        $usuarioId = $request->user()->id;
        $anio = $request->filled('anio')
            ? str_pad((string) ((int) $request->anio % 100), 2, '0', STR_PAD_LEFT)
            : now()->format('y');
        $prefijo = "P{$usuarioId}-{$anio}-";

        $consecutivo = Venta::where('numero_orden', 'like', $prefijo . '%')
            ->pluck('numero_orden')
            ->map(fn ($folio) => (int) substr($folio, strlen($prefijo)))
            ->max() ?? 0;

        return response()->json([
            'usuario_id' => $usuarioId,
            'anio' => (int) $anio,
            'consecutivo' => $consecutivo,
        ]);
    }

    public function show(Request $request, Venta $venta)
    {
        // Un preventista solo ve los pedidos que levantó o que le toca entregar
        $usuario = $request->user();
        if ((int) $usuario->rol_id !== 1
            && (int) $venta->preventista_vendedor_id !== (int) $usuario->id
            && (int) $venta->preventista_entrega_id !== (int) $usuario->id) {
            return response()->json(['message' => 'No autorizado'], 403);
        }

        $venta->load(['domicilio.cliente', 'vendedor', 'repartidor', 'detalle.producto', 'registrosGps']);

        // Distancia entre donde se levantó el pedido y el domicilio del cliente
        // (las de entrega / no entregado vienen en registros_gps)
        $datos = $venta->toArray();
        $datos['distancia_registro_m'] = RegistroGps::distanciaMetros(
            $venta->latitud_registro,
            $venta->longitud_registro,
            $venta->domicilio
        );
        // El pedido no guarda la precisión; la tiene la visita ligada (pedidos
        // levantados desde la ruta). Si no hay, queda null.
        $datos['precision_registro_m'] = Visita::where('venta_id', $venta->id)->value('precision_m');

        return response()->json($datos);
    }

    // Editar datos generales del pedido (solo antes de imprimir el ticket)
    public function update(Request $request, Venta $venta)
    {
        if ($venta->estado !== 'pendiente') {
            throw ValidationException::withMessages([
                'venta' => ['Solo se puede editar un pedido pendiente.'],
            ]);
        }

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
            'fecha_hora_registro' => 'nullable|date',
        ]);

        if ($venta->estado !== 'en_ruta') {
            throw ValidationException::withMessages([
                'estado' => ['Solo se puede entregar un pedido que está en ruta.'],
            ]);
        }

        // Hora en que se entregó (si fue sin conexión, llega después)
        $momento = $this->momentoRegistro($request->input('fecha_hora_registro'));

        DB::transaction(function () use ($request, $venta, $momento) {
            $venta->update([
                'estado' => 'entregado',
                'fecha_entrega' => $momento->toDateString(),
                'hora_entrega' => $momento->toTimeString(),
            ]);

            // Guardar dónde estaba el preventista al entregar
            RegistroGps::desdeRequest($request, 'entrega', $venta->domicilio, [
                'venta_id' => $venta->id,
                'created_at' => $momento,
            ]);

            $this->actualizarParadaEntrega($venta, 'visitada');

            // Si con esta venta el preventista alcanzó su cuota semanal
            // (semana del pedido), se genera su comisión automáticamente
            Cuota::vigente($venta->preventista_vendedor_id, $venta->fecha_hora)?->evaluar();
        });

        return response()->json($venta);
    }

    // El cliente no recibió el pedido: regresa a "pendiente" para reprogramar
    public function marcarNoEntregado(Request $request, Venta $venta)
    {
        $request->validate([
            'latitud'   => 'nullable|numeric|between:-90,90',
            'longitud'  => 'nullable|numeric|between:-180,180',
            'precision' => 'nullable|numeric|min:0',
            'fecha_hora_registro' => 'nullable|date',
        ]);

        if ($venta->estado !== 'en_ruta') {
            throw ValidationException::withMessages([
                'estado' => ['Solo un pedido en ruta puede regresar a pendiente.'],
            ]);
        }

        $momento = $this->momentoRegistro($request->input('fecha_hora_registro'));

        DB::transaction(function () use ($request, $venta, $momento) {
            $venta->update(['estado' => 'pendiente']);

            // Guardar dónde estaba el preventista al reportar que no se entregó
            RegistroGps::desdeRequest($request, 'no_entregado', $venta->domicilio, [
                'venta_id' => $venta->id,
                'created_at' => $momento,
            ]);

            // La parada queda atendida ("No entregado" en el panel); el pedido
            // regresa a pendiente para asignarlo de nuevo
            $this->actualizarParadaEntrega($venta, 'no_disponible');
        });

        return response()->json($venta);
    }

    // Refleja la entrega en la parada de la ruta de entregas que lleva este
    // pedido (la más reciente), para que el panel vea el avance de la ruta
    private function actualizarParadaEntrega(Venta $venta, string $estado): void
    {
        $sinAtender = $estado === 'visitada' ? ['pendiente', 'no_disponible'] : ['pendiente'];

        $detalle = DetalleRuta::with('ruta')
            ->where('venta_id', $venta->id)
            ->whereIn('estado', $sinAtender)
            ->latest('id')
            ->first();

        if (!$detalle) {
            return;
        }

        $detalle->update(['estado' => $estado]);
        $detalle->ruta->actualizarEstado();
    }

    // Cancelar el pedido (solo si aún no ha sido entregado)
    public function cancelar(Request $request, Venta $venta)
    {
        $datos = $request->validate([
            'motivo_cancelacion' => 'nullable|string|max:255',
        ]);

        if (!in_array($venta->estado, ['pendiente', 'en_ruta'], true)) {
            throw ValidationException::withMessages([
                'estado' => ['Solo se puede cancelar un pedido pendiente o en ruta.'],
            ]);
        }

        DB::transaction(function () use ($venta, $datos) {
            $venta->update([
                'estado' => 'cancelado',
                'motivo_cancelacion' => $datos['motivo_cancelacion'] ?? null,
            ]);

            // Si estaba en una ruta de entregas, su parada queda atendida
            // (el panel la muestra como "Cancelado") para que la ruta pueda
            // cerrarse
            $this->actualizarParadaEntrega($venta, 'no_disponible');
        });

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
}
