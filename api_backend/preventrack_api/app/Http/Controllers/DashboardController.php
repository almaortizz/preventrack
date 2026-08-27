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
}
