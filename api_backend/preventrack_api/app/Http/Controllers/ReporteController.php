<?php

namespace App\Http\Controllers;

use App\Exports\ClientesExport;
use App\Exports\ComisionesExport;
use App\Exports\JornadasExport;
use App\Exports\ProductosExport;
use App\Exports\VentasExport;
use App\Models\Venta;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class ReporteController extends Controller
{
    public function ventas(Request $request)
    {
        $request->validate([
            'fecha_inicio' => 'nullable|date',
            'fecha_fin' => 'nullable|date|after_or_equal:fecha_inicio',
            'preventista_vendedor_id' => 'nullable|exists:usuarios,id',
            'colorear_por_preventista' => 'nullable|boolean',
        ]);

        $nombreArchivo = 'reporte_ventas_' . now()->format('Y-m-d_His') . '.xlsx';

        return Excel::download(
            new VentasExport(
                $request->fecha_inicio,
                $request->fecha_fin,
                $request->preventista_vendedor_id,
                $request->boolean('colorear_por_preventista')
            ),
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

    // Junta todos los pedidos de un día en una sola hoja, agrupados por
    // cliente/pedido con sus productos, zona y total — dejando una
    // columna de proveedor en blanco para llenarla a mano, como la
    // "Hoja de pedidos y presupuestos" que ya usaban.
    public function hojaPedidosDia(Request $request)
    {
        $datos = $request->validate([
            'fecha' => 'required|date',
        ]);

        $ventas = Venta::with(['domicilio.cliente', 'detalle.producto'])
            ->whereDate('fecha_hora', $datos['fecha'])
            ->where('estado', '!=', 'cancelado')
            ->orderBy('fecha_hora')
            ->get();

        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Hoja de pedidos');

        $sheet->getColumnDimension('A')->setWidth(6);
        $sheet->getColumnDimension('B')->setWidth(12);
        $sheet->getColumnDimension('C')->setWidth(28);
        $sheet->getColumnDimension('D')->setWidth(14);
        $sheet->getColumnDimension('E')->setWidth(12);
        $sheet->getColumnDimension('F')->setWidth(12);
        $sheet->getColumnDimension('G')->setWidth(20);
        $sheet->getColumnDimension('H')->setWidth(16);
        $sheet->getColumnDimension('I')->setWidth(12);
        $sheet->getColumnDimension('J')->setWidth(6);
        $sheet->getColumnDimension('K')->setWidth(16);

        $sheet->setCellValue('A1', 'HOJA DE PEDIDOS — ' . \Carbon\Carbon::parse($datos['fecha'])->format('d/m/Y'));
        $sheet->mergeCells('A1:K1');
        $sheet->getStyle('A1')->getFont()->setBold(true)->setSize(14);

        $filaEncabezado = 3;
        $encabezados = ['P', 'CODIGO', 'CONCEPTO', 'PROV', 'PRECIO', 'SUB TOTAL', 'DOMICILIO', 'ZONA', 'CANTIDAD', 'N°', 'PEDIDO NUMERO'];
        $columnas = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K'];
        foreach ($encabezados as $i => $texto) {
            $sheet->setCellValue($columnas[$i] . $filaEncabezado, $texto);
        }
        $sheet->getStyle('A' . $filaEncabezado . ':K' . $filaEncabezado)->getFont()->setBold(true);
        $sheet->getStyle('A' . $filaEncabezado . ':K' . $filaEncabezado)
            ->getFill()->setFillType(Fill::FILL_SOLID)->getStartColor()->setRGB('1A3D6D');
        $sheet->getStyle('A' . $filaEncabezado . ':K' . $filaEncabezado)->getFont()->getColor()->setRGB('FFFFFF');

        $paleta = ['FADBD8', 'D6EAF8', 'FCF3CF', 'D5F5E3'];
        $fila = $filaEncabezado + 1;
        $numeroPedido = 1;
        $totalUnidades = 0;
        $totalGeneral = 0;

        foreach ($ventas as $venta) {
            $color = $paleta[($numeroPedido - 1) % count($paleta)];
            $cliente = $venta->domicilio->cliente ?? null;
            $filaInicio = $fila;

            foreach ($venta->detalle as $item) {
                $sheet->setCellValue('A' . $fila, $item->cantidad);
                $sheet->setCellValue('B' . $fila, $item->producto->codigo ?? '');
                $sheet->setCellValue('C' . $fila, $item->producto->nombre ?? '');
                $sheet->setCellValue('E' . $fila, (float) $item->precio_unitario);
                $sheet->setCellValue('F' . $fila, (float) $item->subtotal);
                $sheet->getStyle('E' . $fila . ':F' . $fila)->getNumberFormat()->setFormatCode('$#,##0.00');
                $totalUnidades += (float) $item->cantidad;
                $fila++;
            }

            $filaResumen = $fila - 1;
            if ($filaResumen >= $filaInicio) {
                $sheet->setCellValue('G' . $filaResumen, $cliente->nombre_negocio ?? '—');
                $sheet->setCellValue('H' . $filaResumen, $venta->domicilio->municipio ?? '—');
                $sheet->setCellValue('I' . $filaResumen, (float) $venta->total);
                $sheet->getStyle('I' . $filaResumen)->getNumberFormat()->setFormatCode('$#,##0.00');
                $sheet->setCellValue('J' . $filaResumen, $numeroPedido);
                $sheet->setCellValue('K' . $filaResumen, $venta->numero_orden);
                $sheet->getStyle('G' . $filaResumen . ':K' . $filaResumen)->getFont()->setBold(true);
            }

            $sheet->getStyle('A' . $filaInicio . ':K' . $filaResumen)
                ->getFill()->setFillType(Fill::FILL_SOLID)->getStartColor()->setRGB($color);

            $totalGeneral += (float) $venta->total;
            $numeroPedido++;
        }

        $rangoTabla = 'A' . $filaEncabezado . ':K' . ($fila - 1);
        $sheet->getStyle($rangoTabla)->getBorders()->getAllBorders()->setBorderStyle(Border::BORDER_THIN);

        $filaTotal = $fila + 1;
        $sheet->setCellValue('A' . $filaTotal, $totalUnidades);
        $sheet->setCellValue('F' . $filaTotal, 'TOTAL DEL DÍA');
        $sheet->setCellValue('I' . $filaTotal, $totalGeneral);
        $sheet->getStyle('I' . $filaTotal)->getNumberFormat()->setFormatCode('$#,##0.00');
        $sheet->getStyle('A' . $filaTotal . ':K' . $filaTotal)->getFont()->setBold(true);

        $writer = new Xlsx($spreadsheet);
        $nombreArchivo = 'hoja_pedidos_' . $datos['fecha'] . '.xlsx';

        return response()->streamDownload(function () use ($writer) {
            $writer->save('php://output');
        }, $nombreArchivo, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }
}
