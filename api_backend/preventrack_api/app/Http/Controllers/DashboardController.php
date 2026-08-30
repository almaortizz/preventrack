<?php

namespace App\Http\Controllers;

use App\Models\Venta;
use App\Models\Cliente;
use App\Models\Producto;
use Illuminate\Http\Request;
use Carbon\Carbon;
use App\Models\Cuota;

class DashboardController extends Controller
{
    public function index()
    {
        $hoy = Carbon::now('America/Mexico_City')->toDateString();

        $inicioSemana = Carbon::now('America/Mexico_City')->startOfWeek()->toDateString();
        $finSemana = Carbon::now('America/Mexico_City')->endOfWeek()->toDateString();

        $inicioMes = Carbon::now('America/Mexico_City')->startOfMonth()->toDateString();
        $finMes = Carbon::now('America/Mexico_City')->endOfMonth()->toDateString();

        // --- Contadores por estado ---
        $pendientes = Venta::where('estado', 'pendiente')->count();
        $enRuta = Venta::where('estado', 'en_ruta')->count();

        $entregadosHoy = Venta::where('estado', 'entregado')
            ->whereDate('fecha_entrega', $hoy)
            ->count();

        $canceladosHoy = Venta::where('estado', 'cancelado')
            ->whereDate('updated_at', $hoy)
            ->count();

        // --- Ventas en dinero ---
        $totalVentasHoy = Venta::where('estado', 'entregado')
            ->whereDate('fecha_entrega', $hoy)
            ->sum('total');

        $totalVentasSemana = Venta::where('estado', 'entregado')
            ->whereDate('fecha_entrega', '>=', $inicioSemana)
            ->whereDate('fecha_entrega', '<=', $finSemana)
            ->sum('total');

        $totalVentasMes = Venta::where('estado', 'entregado')
            ->whereDate('fecha_entrega', '>=', $inicioMes)
            ->whereDate('fecha_entrega', '<=', $finMes)
            ->sum('total');

        // --- Últimos 10 pedidos ---
        $ultimosPedidos = Venta::with(['domicilio', 'vendedor'])
            ->orderBy('created_at', 'desc')
            ->take(10)
            ->get();

        // --- Totales generales ---
        $totalClientes = Cliente::count();
        $totalProductos = Producto::count();

                // --- Cuota semanal ---
        $cuota = Cuota::where('fecha_inicio_semana', '<=', $hoy)
            ->where('fecha_fin_semana', '>=', $hoy)
            ->where('usuario_id', auth('sanctum')->id())
            ->first();

        $ventasSemana = $totalVentasSemana;
        $cuotaData = null;
        if ($cuota) {
            $cuotaData = [
                'monto_objetivo' => round($cuota->monto_objetivo, 2),
                'monto_comision' => round($cuota->monto_comision, 2),
                'ventas_semana'  => round($ventasSemana, 2),
                'cumplida'       => $ventasSemana >= $cuota->monto_objetivo,
                'porcentaje'     => $cuota->monto_objetivo > 0 ? round(($ventasSemana / $cuota->monto_objetivo) * 100, 1) : 0,
                'faltante'       => round(max(0, $cuota->monto_objetivo - $ventasSemana), 2),
            ];
        }

        return response()->json([
            'contadores' => [
                'pendientes'     => $pendientes,
                'en_ruta'        => $enRuta,
                'entregados_hoy' => $entregadosHoy,
                'cancelados_hoy' => $canceladosHoy,
            ],
            'cuota' => $cuotaData,
            'ultimos_pedidos' => $ultimosPedidos,
            'totales' => [
                'clientes'  => $totalClientes,
                'productos' => $totalProductos,
            ],
            'ventas' => [
                'total_hoy'    => round($totalVentasHoy, 2),
                'total_semana' => round($totalVentasSemana, 2),
                'total_mes'    => round($totalVentasMes, 2),
            ],
            'ultimos_pedidos' => $ultimosPedidos,
            'totales' => [
                'clientes'  => $totalClientes,
                'productos' => $totalProductos,
            ],
        ]);
    }

        public function rutaDelDia()
    {
        $hoy = Carbon::now('America/Mexico_City')->toDateString();
        $userId = auth('sanctum')->id();

        $ruta = \App\Models\Ruta::with(['detalle.domicilio.cliente'])
            ->where('usuario_id', $userId)
            ->where('fecha', $hoy)
            ->first();

        if (!$ruta) {
            return response()->json(['ruta' => null]);
        }

        return response()->json(['ruta' => $ruta]);
    }

        public function dashboardAdmin(Request $request)
    {
        // Solo admin puede acceder
        if ($request->user()->rol_id !== 1) {
            return response()->json(['message' => 'No autorizado'], 403);
        }

        $hoy = Carbon::now('America/Mexico_City')->toDateString();
        $inicioSemana = Carbon::now('America/Mexico_City')->startOfWeek()->toDateString();
        $finSemana = Carbon::now('America/Mexico_City')->endOfWeek()->toDateString();

        // ── Ventas del día (entregadas) ──
        $ventasHoyQuery = Venta::where('estado', 'entregado')
            ->whereDate('fecha_entrega', $hoy);
        $totalVentasHoy = $ventasHoyQuery->sum('total');
        $cantidadVentasHoy = $ventasHoyQuery->count();

        // ── Ventas de la semana (entregadas) ──
        $ventasSemanaQuery = Venta::where('estado', 'entregado')
            ->whereDate('fecha_entrega', '>=', $inicioSemana)
            ->whereDate('fecha_entrega', '<=', $finSemana);
        $totalVentasSemana = $ventasSemanaQuery->sum('total');
        $cantidadVentasSemana = $ventasSemanaQuery->count();

        // ── Entregas ──
        $entregasPendientes = Venta::where('estado', 'en_ruta')->count();
        $entregasCompletadas = Venta::where('estado', 'entregado')
            ->whereDate('fecha_entrega', $hoy)->count();
        $entregasCanceladas = Venta::where('estado', 'cancelado')
            ->whereDate('updated_at', $hoy)->count();

        // ── Preventistas activos (con jornada activa hoy) ──
        $jornadasActivas = \App\Models\Jornada::whereDate('fecha', $hoy)
            ->whereNotNull('hora_inicio')
            ->whereNull('hora_fin')
            ->count();

        // estado es enum 'activo'/'inactivo', no boolean
        $totalPreventistas = \App\Models\Usuario::where('rol_id', 2)
            ->where('estado', 'activo')->count();

        // ── Cumplimiento de cuota semanal por preventista ──
        $cuotaObjetivo = 6500;
        $preventistas = \App\Models\Usuario::where('rol_id', 2)
            ->where('estado', 'activo')->get();

        $resumenCuotas = [];
        $cumplenCuota = 0;

        foreach ($preventistas as $prev) {
            $cuotaPrev = Cuota::where('usuario_id', $prev->id)
                ->where('fecha_inicio_semana', '<=', $hoy)
                ->where('fecha_fin_semana', '>=', $hoy)
                ->first();

            $objetivo = $cuotaPrev ? $cuotaPrev->monto_objetivo : $cuotaObjetivo;

            // La FK es preventista_vendedor_id, no usuario_id
            $ventasPrev = Venta::where('preventista_vendedor_id', $prev->id)
                ->where('estado', 'entregado')
                ->whereDate('fecha_entrega', '>=', $inicioSemana)
                ->whereDate('fecha_entrega', '<=', $finSemana)
                ->sum('total');

            $cumple = $ventasPrev >= $objetivo;
            if ($cumple) $cumplenCuota++;

            $resumenCuotas[] = [
                'id'            => $prev->id,
                'nombre'        => $prev->nombre . ' ' . $prev->apellidos,
                'venta_semanal' => round($ventasPrev, 2),
                'objetivo'      => round($objetivo, 2),
                'porcentaje'    => $objetivo > 0 ? round(($ventasPrev / $objetivo) * 100, 1) : 0,
                'cumple'        => $cumple,
            ];
        }

        // Ordenar por venta semanal descendente (ranking)
        usort($resumenCuotas, fn($a, $b) => $b['venta_semanal'] <=> $a['venta_semanal']);

        // ── Últimos 10 pedidos (de todos los preventistas) ──
        $ultimosPedidos = Venta::with(['vendedor', 'domicilio.cliente'])
            ->orderBy('created_at', 'desc')
            ->take(10)
            ->get()
            ->map(function ($v) {
                $clienteNombre = 'N/A';
                if ($v->domicilio && $v->domicilio->cliente) {
                    $clienteNombre = $v->domicilio->cliente->nombre_negocio;
                }

                return [
                    'id'          => $v->id,
                    'folio'       => $v->numero_orden,
                    'preventista' => $v->vendedor ? $v->vendedor->nombre : 'N/A',
                    'cliente'     => $clienteNombre,
                    'total'       => $v->total,
                    'estado'      => $v->estado,
                    'fecha'       => $v->created_at->format('d/m/Y H:i'),
                ];
            });

        // ── Alertas anti-fraude ──
        // Solo se activa si las columnas existen en la tabla
        $alertasFraude = 0;
        try {
            $alertasFraude = Venta::whereNotNull('fecha_inicio_creacion')
                ->whereNotNull('fecha_fin_creacion')
                ->whereDate('created_at', $hoy)
                ->get()
                ->filter(function ($v) {
                    $inicio = Carbon::parse($v->fecha_inicio_creacion);
                    $fin = Carbon::parse($v->fecha_fin_creacion);
                    return $inicio->diffInSeconds($fin) < 30;
                })
                ->count();
        } catch (\Exception $e) {
            // Columnas aún no existen, se ignora
            $alertasFraude = 0;
        }

        return response()->json([
            'ventas_hoy' => [
                'total'    => round($totalVentasHoy, 2),
                'cantidad' => $cantidadVentasHoy,
            ],
            'ventas_semana' => [
                'total'    => round($totalVentasSemana, 2),
                'cantidad' => $cantidadVentasSemana,
            ],
            'entregas' => [
                'pendientes'   => $entregasPendientes,
                'completadas'  => $entregasCompletadas,
                'canceladas'   => $entregasCanceladas,
            ],
            'equipo' => [
                'preventistas_activos' => $jornadasActivas,
                'total_preventistas'   => $totalPreventistas,
            ],
            'cuota' => [
                'objetivo'   => $cuotaObjetivo,
                'cumplen'    => $cumplenCuota,
                'no_cumplen' => $totalPreventistas - $cumplenCuota,
                'detalle'    => $resumenCuotas,
            ],
            'ultimos_pedidos' => $ultimosPedidos,
            'alertas_fraude'  => $alertasFraude,
        ]);
    }
}
