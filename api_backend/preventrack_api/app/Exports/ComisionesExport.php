<?php

namespace App\Exports;

use App\Models\Comision;
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

class ComisionesExport implements FromCollection, WithHeadings, WithMapping, WithStyles, WithColumnWidths, WithTitle
{
    public function title(): string
    {
        return 'Reporte de Comisiones';
    }

    public function collection()
    {
        return Comision::with(['usuario', 'cuota'])->orderByDesc('fecha_generada')->get();
    }

    public function headings(): array
    {
        return [
            'Colaborador', 'Semana', 'Meta de Venta', 'Monto Alcanzado',
            'Comisión', 'Fecha Generada', 'Estado',
        ];
    }

    public function map($comision): array
    {
        $semana = $comision->cuota
            ? $comision->cuota->fecha_inicio_semana->format('d/m') . ' - ' . $comision->cuota->fecha_fin_semana->format('d/m/Y')
            : '';

        return [
            $comision->usuario->nombre . ' ' . $comision->usuario->apellidos,
            $semana,
            $comision->cuota->monto_objetivo ?? '',
            $comision->cuota->monto_alcanzado ?? '',
            $comision->monto,
            $comision->fecha_generada->format('Y-m-d'),
            ucfirst($comision->estado),
        ];
    }

    public function columnWidths(): array
    {
        return [
            'A' => 25, 'B' => 22, 'C' => 15, 'D' => 16,
            'E' => 14, 'F' => 15, 'G' => 12,
        ];
    }

    public function styles(Worksheet $sheet)
    {
        $empresa = Empresa::first();
        $nombreEmpresa = $empresa->nombre ?? 'PREVENTRACK';

        $sheet->insertNewRowBefore(1, 3);
        $sheet->setCellValue('A1', $nombreEmpresa);
        $sheet->mergeCells('A1:G1');
        $sheet->setCellValue('A2', 'Reporte de Comisiones');
        $sheet->mergeCells('A2:G2');
        $sheet->setCellValue('A3', 'Generado el: ' . now()->format('d/m/Y H:i'));
        $sheet->mergeCells('A3:G3');

        $sheet->getStyle('A1')->getFont()->setBold(true)->setSize(16);
        $sheet->getStyle('A2')->getFont()->setBold(true)->setSize(12);
        $sheet->getStyle('A3')->getFont()->setItalic(true)->setSize(9);
        $sheet->getStyle('A1:A3')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

        $sheet->getStyle('A4:G4')->getFont()->setBold(true)->setColor(
            new \PhpOffice\PhpSpreadsheet\Style\Color(\PhpOffice\PhpSpreadsheet\Style\Color::COLOR_WHITE)
        );
        $sheet->getStyle('A4:G4')->getFill()
            ->setFillType(Fill::FILL_SOLID)
            ->getStartColor()->setRGB('2E4E9E');

        return [];
    }
}
