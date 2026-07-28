<?php

namespace App\Exports;

use App\Models\Empresa;
use App\Models\Jornada;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;
use Maatwebsite\Excel\Concerns\WithStyles;
use Maatwebsite\Excel\Concerns\WithColumnWidths;
use Maatwebsite\Excel\Concerns\WithTitle;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Fill;

class JornadasExport implements FromCollection, WithHeadings, WithMapping, WithStyles, WithColumnWidths, WithTitle
{
    protected $fechaInicio;
    protected $fechaFin;

    public function __construct($fechaInicio = null, $fechaFin = null)
    {
        $this->fechaInicio = $fechaInicio;
        $this->fechaFin = $fechaFin;
    }

    public function title(): string
    {
        return 'Jornadas Laborales';
    }

    public function collection()
    {
        $query = Jornada::with('usuario');

        if ($this->fechaInicio && $this->fechaFin) {
            $query->whereBetween('fecha', [$this->fechaInicio, $this->fechaFin]);
        }

        return $query->orderBy('fecha')->get();
    }

    public function headings(): array
    {
        return [
            'Fecha', 'Colaborador', 'Hora Inicio', 'Inicio Comida',
            'Fin Comida', 'Hora Fin', 'Horas Laboradas',
        ];
    }

    public function map($jornada): array
    {
        $horas = '';
        if ($jornada->hora_inicio && $jornada->hora_fin) {
            $minutosComida = 0;
            if ($jornada->hora_inicio_comida && $jornada->hora_fin_comida) {
                $minutosComida = $jornada->hora_fin_comida->diffInMinutes($jornada->hora_inicio_comida);
            }
            $minutosTotales = $jornada->hora_fin->diffInMinutes($jornada->hora_inicio) - $minutosComida;
            $horas = round($minutosTotales / 60, 2);
        }

        return [
            $jornada->fecha->format('Y-m-d'),
            $jornada->usuario->nombre . ' ' . $jornada->usuario->apellidos,
            $jornada->hora_inicio ? $jornada->hora_inicio->format('H:i') : '',
            $jornada->hora_inicio_comida ? $jornada->hora_inicio_comida->format('H:i') : '',
            $jornada->hora_fin_comida ? $jornada->hora_fin_comida->format('H:i') : '',
            $jornada->hora_fin ? $jornada->hora_fin->format('H:i') : '',
            $horas,
        ];
    }

    public function columnWidths(): array
    {
        return [
            'A' => 12, 'B' => 25, 'C' => 12, 'D' => 14,
            'E' => 12, 'F' => 12, 'G' => 16,
        ];
    }

    public function styles(Worksheet $sheet)
    {
        $empresa = Empresa::first();
        $nombreEmpresa = $empresa->nombre ?? 'PREVENTRACK';

        $sheet->insertNewRowBefore(1, 3);
        $sheet->setCellValue('A1', $nombreEmpresa);
        $sheet->mergeCells('A1:G1');
        $sheet->setCellValue('A2', 'Reporte de Jornadas Laborales');
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
