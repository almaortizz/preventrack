<?php

namespace App\Http\Controllers;

use App\Models\Venta;
use App\Models\Cliente;
use App\Models\Producto;
use Illuminate\Http\Request;
use Carbon\Carbon;

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

        return response()->json([
            'contadores' => [
                'pendientes'     => $pendientes,
                'en_ruta'        => $enRuta,
                'entregados_hoy' => $entregadosHoy,
                'cancelados_hoy' => $canceladosHoy,
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
}
