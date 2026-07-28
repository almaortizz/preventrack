<?php

namespace App\Http\Controllers;

use App\Exports\ClientesExport;
use App\Exports\ComisionesExport;
use App\Exports\JornadasExport;
use App\Exports\ProductosExport;
use App\Exports\VentasExport;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;

class ReporteController extends Controller
{
    public function ventas(Request $request)
    {
        $request->validate([
            'fecha_inicio' => 'nullable|date',
            'fecha_fin' => 'nullable|date|after_or_equal:fecha_inicio',
        ]);

        $nombreArchivo = 'reporte_ventas_' . now()->format('Y-m-d_His') . '.xlsx';

        return Excel::download(
            new VentasExport($request->fecha_inicio, $request->fecha_fin),
            $nombreArchivo
        );
    }

    public function clientes()
    {
        $nombreArchivo = 'reporte_clientes_' . now()->format('Y-m-d_His') . '.xlsx';

        return Excel::download(new ClientesExport(), $nombreArchivo);
    }

    public function productos()
    {
        $nombreArchivo = 'reporte_productos_' . now()->format('Y-m-d_His') . '.xlsx';

        return Excel::download(new ProductosExport(), $nombreArchivo);
    }

    public function jornadas(Request $request)
    {
        $request->validate([
            'fecha_inicio' => 'nullable|date',
            'fecha_fin' => 'nullable|date|after_or_equal:fecha_inicio',
        ]);

        $nombreArchivo = 'reporte_jornadas_' . now()->format('Y-m-d_His') . '.xlsx';

        return Excel::download(
            new JornadasExport($request->fecha_inicio, $request->fecha_fin),
            $nombreArchivo
        );
    }

    public function comisiones()
    {
        $nombreArchivo = 'reporte_comisiones_' . now()->format('Y-m-d_His') . '.xlsx';

        return Excel::download(new ComisionesExport(), $nombreArchivo);
    }
}
