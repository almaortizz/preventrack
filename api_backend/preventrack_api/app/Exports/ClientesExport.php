<?php

namespace App\Exports;

use App\Models\Cliente;
use App\Models\Empresa;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;
use Maatwebsite\Excel\Concerns\WithStyles;
use Maatwebsite\Excel\Concerns\WithColumnWidths;
use Maatwebsite\Excel\Concerns\WithTitle;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Fill;

class ClientesExport implements FromCollection, WithHeadings, WithMapping, WithStyles, WithColumnWidths, WithTitle
{
    public function title(): string
    {
        return 'Reporte de Clientes';
    }

    public function collection()
    {
        return Cliente::with('domicilios')->orderBy('nombre_negocio')->get();
    }

    public function headings(): array
    {
        return [
            'Folio', 'Nombre del Negocio', 'Propietario', 'Razón Social',
            'RFC', 'Teléfono', 'Zona', 'Domicilios', 'Estado',
        ];
    }

    public function map($cliente): array
    {
        $direcciones = $cliente->domicilios->pluck('direccion')->implode(' | ');

        return [
            $cliente->folio,
            $cliente->nombre_negocio,
            $cliente->propietario,
            $cliente->razon_social,
            $cliente->rfc,
            $cliente->telefono,
            $cliente->zona,
            $direcciones,
            ucfirst($cliente->estado),
        ];
    }

    public function columnWidths(): array
    {
        return [
            'A' => 12, 'B' => 25, 'C' => 20, 'D' => 25,
            'E' => 15, 'F' => 15, 'G' => 15, 'H' => 40, 'I' => 12,
        ];
    }

    public function styles(Worksheet $sheet)
    {
        $empresa = Empresa::first();
        $nombreEmpresa = $empresa->nombre ?? 'PREVENTRACK';

        $sheet->insertNewRowBefore(1, 3);
        $sheet->setCellValue('A1', $nombreEmpresa);
        $sheet->mergeCells('A1:I1');
        $sheet->setCellValue('A2', 'Reporte de Clientes');
        $sheet->mergeCells('A2:I2');
        $sheet->setCellValue('A3', 'Generado el: ' . now()->format('d/m/Y H:i'));
        $sheet->mergeCells('A3:I3');

        $sheet->getStyle('A1')->getFont()->setBold(true)->setSize(16);
        $sheet->getStyle('A2')->getFont()->setBold(true)->setSize(12);
        $sheet->getStyle('A3')->getFont()->setItalic(true)->setSize(9);
        $sheet->getStyle('A1:A3')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

        $sheet->getStyle('A4:I4')->getFont()->setBold(true)->setColor(
            new \PhpOffice\PhpSpreadsheet\Style\Color(\PhpOffice\PhpSpreadsheet\Style\Color::COLOR_WHITE)
        );
        $sheet->getStyle('A4:I4')->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setRGB('2E4E9E');

        return [];
    }
}
