<?php

namespace App\Http\Controllers;

use App\Models\Venta;
use Barryvdh\DomPDF\Facade\Pdf;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Worksheet\Drawing;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class RemisionController extends Controller
{
    // Genera el PDF de la remisión (nota de entrega) de un pedido,
    // con el membrete de la empresa, para imprimir o mandar por WhatsApp.
    public function generar(Venta $venta)
    {
        $venta->load(['domicilio.cliente', 'vendedor', 'detalle.producto']);

        $cliente = $venta->domicilio->cliente;
        $domicilio = $venta->domicilio;

        $subtotal = $venta->detalle->sum('subtotal');

        $logoPath = public_path('img/logo-bella-luz.jpg');

        $pdf = Pdf::loadView('remisiones.pdf', [
            'venta' => $venta,
            'cliente' => $cliente,
            'domicilio' => $domicilio,
            'subtotal' => $subtotal,
            'logoPath' => $logoPath,
        ])->setPaper('letter', 'portrait');

        $nombreArchivo = 'remision_' . $venta->numero_orden . '.pdf';

        return $pdf->stream($nombreArchivo);
    }

    // Genera la remisión en Excel, replicando el formato de la plantilla
    // original (DISTRIBUIDORA "BELLA LUZ") pero con los datos reales del
    // pedido.
    public function excel(Venta $venta)
    {
        $venta->load(['domicilio.cliente', 'vendedor', 'detalle.producto']);

        $cliente = $venta->domicilio->cliente;
        $domicilio = $venta->domicilio;

        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Remision');

        // Anchos de columna
        $sheet->getColumnDimension('A')->setWidth(4);
        $sheet->getColumnDimension('B')->setWidth(14);
        $sheet->getColumnDimension('C')->setWidth(12);
        $sheet->getColumnDimension('D')->setWidth(40);
        $sheet->getColumnDimension('E')->setWidth(12);
        $sheet->getColumnDimension('F')->setWidth(14);

        // --- Encabezado de la empresa ---
        $sheet->setCellValue('B1', 'DISTRIBUIDORA');
        $sheet->mergeCells('B1:C1');
        $sheet->getStyle('B1')->getFont()->setBold(true)->setSize(16);

        $sheet->setCellValue('D1', '"BELLA LUZ"');
        $sheet->getStyle('D1')->getFont()->setBold(true)->setSize(24);
        $sheet->getStyle('D1')->getFont()->getColor()->setRGB('1A3D6D');

        $sheet->setCellValue('B4', 'R.F.C. HEAA760906DJ4');
        $sheet->mergeCells('B4:D4');
        $sheet->setCellValue('B5', 'CALLE 95 ORIENTE # 1015-2');
        $sheet->mergeCells('B5:D5');
        $sheet->setCellValue('B6', 'COLONIA GRANJAS EJIDALES SAN ISIDRO');
        $sheet->mergeCells('B6:D6');
        $sheet->setCellValue('B7', 'PUEBLA PUE. C.P. 72587');
        $sheet->mergeCells('B7:D7');
        $sheet->setCellValue('B8', 'CEL. 22 24 63 35 56');
        $sheet->getStyle('B8')->getFont()->setBold(true);
        $sheet->setCellValue('B9', 'WhatsApp');
        $sheet->getStyle('B9')->getFont()->getColor()->setRGB('25D366');
        $sheet->getStyle('B9')->getFont()->setBold(true);

        // Logo de la empresa
        $logoPath = public_path('img/logo-bella-luz.jpg');
        if (file_exists($logoPath)) {
            $drawing = new Drawing();
            $drawing->setName('Logo');
            $drawing->setPath($logoPath);
            $drawing->setHeight(95);
            $drawing->setCoordinates('E2');
            $drawing->setWorksheet($sheet);
        }

        // --- Datos del comprador ---
        $sheet->setCellValue('B10', 'DATOS DEL COMPRADOR O DESTINATARIO');
        $sheet->mergeCells('B10:D10');
        $sheet->getStyle('B10')->getFont()->setBold(true)->setSize(12);

        $sheet->setCellValue('B11', 'RAZON SOCIAL:');
        $sheet->setCellValue('C11', $cliente->razon_social ?: $cliente->nombre_negocio);
        $sheet->mergeCells('C11:D11');
        $sheet->setCellValue('E11', '# CLIENTE');
        $sheet->setCellValue('G11', $cliente->folio ?? '—');

        $sheet->setCellValue('B12', 'CLIENTE:');
        $sheet->setCellValue('C12', $cliente->nombre_negocio);
        $sheet->mergeCells('C12:D12');
        $sheet->setCellValue('E12', '# REMISION');
        $sheet->setCellValue('F12', $venta->numero_orden);
        $sheet->getStyle('F12')->getFont()->setBold(true);
        $sheet->getStyle('F12')->getFont()->getColor()->setRGB('C0392B');

        $sheet->setCellValue('B13', 'DOMICILIO:');
        $direccionCompleta = trim(
            $domicilio->direccion . ($domicilio->municipio ? ', ' . $domicilio->municipio : ''),
        );
        $sheet->setCellValue('C13', $direccionCompleta);
        $sheet->mergeCells('C13:D13');

        $sheet->setCellValue('B15', 'FECHA:');
        $sheet->setCellValue('D15', \Carbon\Carbon::parse($venta->fecha_hora)->format('d/m/Y'));

        // --- Tabla de productos ---
        $filaEncabezado = 17;
        $sheet->setCellValue('B' . $filaEncabezado, 'CANTIDAD');
        $sheet->setCellValue('C' . $filaEncabezado, 'CODIGO');
        $sheet->setCellValue('D' . $filaEncabezado, 'CONCEPTO');
        $sheet->setCellValue('E' . $filaEncabezado, 'PRECIO');
        $sheet->setCellValue('F' . $filaEncabezado, 'IMPORTE');
        $sheet->getStyle('B' . $filaEncabezado . ':F' . $filaEncabezado)->getFont()->setBold(true);
        $sheet->getStyle('B' . $filaEncabezado . ':F' . $filaEncabezado)
            ->getFill()->setFillType(Fill::FILL_SOLID)->getStartColor()->setRGB('D6E4F0');

        $fila = $filaEncabezado + 1;
        $numero = 1;
        foreach ($venta->detalle as $item) {
            $sheet->setCellValue('A' . $fila, $numero);
            $sheet->setCellValue('B' . $fila, $item->cantidad);
            $sheet->setCellValue('C' . $fila, $item->producto->codigo ?? '');
            $sheet->setCellValue('D' . $fila, $item->producto->nombre ?? '');
            $sheet->setCellValue('E' . $fila, (float) $item->precio_unitario);
            $sheet->setCellValue('F' . $fila, (float) $item->subtotal);
            $sheet->getStyle('E' . $fila . ':F' . $fila)->getNumberFormat()->setFormatCode('$#,##0.00');
            $numero++;
            $fila++;
        }

        // Deja el mismo "alto" de tabla que la plantilla original (23 filas)
        $filaTotales = max($fila, $filaEncabezado + 24);

        $rangoTabla = 'A' . $filaEncabezado . ':F' . ($filaTotales - 1);
        $sheet->getStyle($rangoTabla)->getBorders()->getAllBorders()->setBorderStyle(Border::BORDER_THIN);

        // --- Totales ---
        $subtotal = $venta->detalle->sum('subtotal');

        $sheet->setCellValue('D' . $filaTotales, 'SUB TOTAL');
        $sheet->setCellValue('E' . $filaTotales, (float) $subtotal);
        $sheet->getStyle('E' . $filaTotales)->getNumberFormat()->setFormatCode('$#,##0.00');

        $filaSiguiente = $filaTotales + 1;
        if ($venta->descuento > 0) {
            $sheet->setCellValue('D' . $filaSiguiente, 'DESCUENTO');
            $sheet->setCellValue('E' . $filaSiguiente, -1 * (float) $venta->descuento);
            $sheet->getStyle('E' . $filaSiguiente)->getNumberFormat()->setFormatCode('$#,##0.00');
            $filaSiguiente++;
        } else {
            $sheet->setCellValue('D' . $filaSiguiente, 'IVA');
            $filaSiguiente++;
        }

        $sheet->setCellValue('D' . $filaSiguiente, 'TOTAL');
        $sheet->getStyle('D' . $filaSiguiente)->getFont()->setBold(true);
        $sheet->setCellValue('E' . $filaSiguiente, (float) $venta->total);
        $sheet->getStyle('E' . $filaSiguiente)->getFont()->setBold(true);
        $sheet->getStyle('E' . $filaSiguiente)->getNumberFormat()->setFormatCode('$#,##0.00');

        $sheet->setCellValue('B' . ($filaSiguiente + 3), 'Email :    angelo13467@gmail.com');

        $writer = new Xlsx($spreadsheet);
        $nombreArchivo = 'remision_' . $venta->numero_orden . '.xlsx';

        return response()->streamDownload(function () use ($writer) {
            $writer->save('php://output');
        }, $nombreArchivo, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }
}
