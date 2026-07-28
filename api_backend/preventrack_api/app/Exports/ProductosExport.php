<?php

namespace App\Exports;

use App\Models\Empresa;
use App\Models\Producto;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;
use Maatwebsite\Excel\Concerns\WithStyles;
use Maatwebsite\Excel\Concerns\WithColumnWidths;
use Maatwebsite\Excel\Concerns\WithTitle;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Fill;

class ProductosExport implements FromCollection, WithHeadings, WithMapping, WithStyles, WithColumnWidths, WithTitle
{
    public function title(): string
    {
        return 'Reporte de Productos';
    }

    public function collection()
    {
        return Producto::with('categoria')->orderBy('nombre')->get();
    }

    public function headings(): array
    {
        return [
            'Código', 'Nombre', 'Descripción', 'Categoría',
            'Precio de Venta', 'Costo', 'Existencia', 'Estado',
        ];
    }

    public function map($producto): array
    {
        return [
            $producto->codigo,
            $producto->nombre,
            $producto->descripcion,
            $producto->categoria->nombre ?? '',
            $producto->precio_venta,
            $producto->costo,
            $producto->stock,
            ucfirst($producto->estado),
        ];
    }

    public function columnWidths(): array
    {
        return [
            'A' => 15, 'B' => 30, 'C' => 30, 'D' => 20,
            'E' => 15, 'F' => 12, 'G' => 12, 'H' => 12,
        ];
    }

    public function styles(Worksheet $sheet)
    {
        $empresa = Empresa::first();
        $nombreEmpresa = $empresa->nombre ?? 'PREVENTRACK';

        $sheet->insertNewRowBefore(1, 3);
        $sheet->setCellValue('A1', $nombreEmpresa);
        $sheet->mergeCells('A1:H1');
        $sheet->setCellValue('A2', 'Reporte de Productos');
        $sheet->mergeCells('A2:H2');
        $sheet->setCellValue('A3', 'Generado el: ' . now()->format('d/m/Y H:i'));
        $sheet->mergeCells('A3:H3');

        $sheet->getStyle('A1')->getFont()->setBold(true)->setSize(16);
        $sheet->getStyle('A2')->getFont()->setBold(true)->setSize(12);
        $sheet->getStyle('A3')->getFont()->setItalic(true)->setSize(9);
        $sheet->getStyle('A1:A3')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

        $sheet->getStyle('A4:H4')->getFont()->setBold(true)->setColor(
            new \PhpOffice\PhpSpreadsheet\Style\Color(\PhpOffice\PhpSpreadsheet\Style\Color::COLOR_WHITE)
        );
        $sheet->getStyle('A4:H4')->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setRGB('2E4E9E');

        return [];
    }
}
