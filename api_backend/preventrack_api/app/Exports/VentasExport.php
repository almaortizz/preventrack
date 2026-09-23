<?php

namespace App\Exports;

use App\Models\Empresa;
use App\Models\Usuario;
use App\Models\Venta;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;
use Maatwebsite\Excel\Concerns\WithStyles;
use Maatwebsite\Excel\Concerns\WithColumnWidths;
use Maatwebsite\Excel\Concerns\WithTitle;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Style\Color;

class VentasExport implements FromCollection, WithHeadings, WithMapping, WithStyles, WithColumnWidths, WithTitle
{
    protected $fechaInicio;
    protected $fechaFin;
    protected $preventistaId;
    protected $colorPorFila;
    protected $coloresFilas = [];

    public function __construct($fechaInicio = null, $fechaFin = null, $preventistaId = null, $colorPorFila = false)
    {
        $this->fechaInicio = $fechaInicio;
        $this->fechaFin = $fechaFin;
        $this->preventistaId = $preventistaId;
        $this->colorPorFila = $colorPorFila;
    }

    public function title(): string
    {
        return 'Reporte de Ventas';
    }

    public function collection()
    {
        $query = Venta::with(['domicilio.cliente', 'vendedor', 'repartidor', 'detalle.producto']);

        if ($this->fechaInicio && $this->fechaFin) {
            $query->whereBetween('fecha_hora', [$this->fechaInicio, $this->fechaFin]);
        }

        if ($this->preventistaId) {
            $query->where('preventista_vendedor_id', $this->preventistaId);
        }

        return $query->orderBy('preventista_vendedor_id')->orderBy('fecha_hora')->get();
    }

    public function headings(): array
    {
        return [
            'Fecha', 'Hora', 'Cliente', 'Código de Producto', 'Nombre del Producto',
            'Cantidad', 'Preventista Vendedor', 'Preventista Entrega', 'Estado',
        ];
    }

    public function map($venta): array
    {
        $filas = [];

        $colorVendedor = null;
        if ($this->colorPorFila && $venta->vendedor) {
            $colorVendedor = !empty($venta->vendedor->color) ? ltrim($venta->vendedor->color, '#') : '2E4E9E';
        }

        foreach ($venta->detalle as $item) {
            $filas[] = [
                $venta->fecha_hora->format('Y-m-d'),
                $venta->fecha_hora->format('H:i'),
                $venta->domicilio->cliente->nombre_negocio ?? '',
                $item->producto->codigo ?? '',
                $item->producto->nombre ?? '',
                $item->cantidad,
                $venta->vendedor->nombre . ' ' . $venta->vendedor->apellidos,
                $venta->repartidor ? $venta->repartidor->nombre . ' ' . $venta->repartidor->apellidos : '',
                ucfirst($venta->estado),
            ];

            if ($this->colorPorFila) {
                $this->coloresFilas[] = $colorVendedor;
            }
        }

        return $filas;
    }

    public function columnWidths(): array
    {
        return [
            'A' => 12, 'B' => 8, 'C' => 25, 'D' => 18, 'E' => 30,
            'F' => 10, 'G' => 22, 'H' => 22, 'I' => 14,
        ];
    }

    public function styles(Worksheet $sheet)
    {
        $empresa = Empresa::first();
        $nombreEmpresa = $empresa->nombre ?? 'PREVENTRACK';

        $colorEncabezado = '2E4E9E';
        $tituloReporte = 'Reporte de Ventas';

        if ($this->preventistaId) {
            $preventista = Usuario::find($this->preventistaId);
            if ($preventista) {
                if (!empty($preventista->color)) {
                    $colorEncabezado = ltrim($preventista->color, '#');
                }
                $tituloReporte = 'Reporte de Ventas — ' . $preventista->nombre . ' ' . $preventista->apellidos;
            }
        } elseif ($this->colorPorFila) {
            $tituloReporte = 'Reporte General de Ventas — Todos los Preventistas';
        }

        // Insertamos 3 filas arriba para el membrete
        $sheet->insertNewRowBefore(1, 3);

        $sheet->setCellValue('A1', $nombreEmpresa);
        $sheet->mergeCells('A1:I1');

        $sheet->setCellValue('A2', $tituloReporte);
        $sheet->mergeCells('A2:I2');

        $sheet->setCellValue('A3', 'Generado el: ' . now()->format('d/m/Y H:i'));
        $sheet->mergeCells('A3:I3');

        $sheet->getStyle('A1')->getFont()->setBold(true)->setSize(16);
        $sheet->getStyle('A2')->getFont()->setBold(true)->setSize(12);
        $sheet->getStyle('A3')->getFont()->setItalic(true)->setSize(9);

        $sheet->getStyle('A1:A3')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);
        $sheet->getStyle('A2:A3')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

        // Encabezados de la tabla (ahora están en la fila 4, por el membrete)
        $sheet->getStyle('A4:I4')->getFont()->setBold(true)->setColor(
            new Color(Color::COLOR_WHITE)
        );
        $sheet->getStyle('A4:I4')->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setRGB($colorEncabezado);

        // Colorear cada fila según el preventista que hizo esa venta
        if ($this->colorPorFila) {
            foreach ($this->coloresFilas as $indice => $colorFila) {
                $numeroFila = 5 + $indice; // fila 5 = primera fila de datos
                if ($colorFila) {
                    $sheet->getStyle("A{$numeroFila}:I{$numeroFila}")->getFill()
                        ->setFillType(Fill::FILL_SOLID)
                        ->getStartColor()->setRGB($colorFila);
                    $sheet->getStyle("A{$numeroFila}:I{$numeroFila}")->getFont()
                        ->getColor()->setRGB($this->colorTextoContraste($colorFila));
                }
            }
        }

        return [];
    }

    private function colorTextoContraste($hex)
    {
        $r = hexdec(substr($hex, 0, 2));
        $g = hexdec(substr($hex, 2, 2));
        $b = hexdec(substr($hex, 4, 2));
        $luminancia = (0.299 * $r + 0.587 * $g + 0.114 * $b) / 255;

        return $luminancia > 0.6 ? '000000' : 'FFFFFF';
    }
}
