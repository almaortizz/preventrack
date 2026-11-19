<?php

namespace App\Exports;

use App\Models\Empresa;
use App\Models\Jornada;
use Carbon\Carbon;
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
            'Fin Comida', 'Hora Fin', 'Horas Laboradas', 'Cierre automático',
        ];
    }

    public function map($jornada): array
    {
        // El modelo entrega las horas como texto: se convierten aquí
        $fecha = fn ($valor) => $valor ? Carbon::parse($valor) : null;
        $inicio = $fecha($jornada->hora_inicio);
        $fin = $fecha($jornada->hora_fin);
        $inicioComida = $fecha($jornada->hora_inicio_comida);
        $finComida = $fecha($jornada->hora_fin_comida);

        $horas = '';
        if ($inicio && $fin) {
            $minutosComida = ($inicioComida && $finComida)
                ? $inicioComida->diffInMinutes($finComida)
                : 0;
            // (Carbon 3: inicio->diffInMinutes(fin) es positivo si fin es después)
            $horas = round(($inicio->diffInMinutes($fin) - $minutosComida) / 60, 2);
        }

        return [
            Carbon::parse($jornada->fecha)->format('Y-m-d'),
            $jornada->usuario->nombre . ' ' . $jornada->usuario->apellidos,
            $inicio ? $inicio->format('H:i') : '',
            $inicioComida ? $inicioComida->format('H:i') : '',
            $finComida ? $finComida->format('H:i') : '',
            $fin ? $fin->format('H:i') : '',
            $horas,
            $jornada->cierre_automatico ? 'Sí' : '',
        ];
    }

    public function columnWidths(): array
    {
        return [
            'A' => 12, 'B' => 25, 'C' => 12, 'D' => 14,
            'E' => 12, 'F' => 12, 'G' => 16, 'H' => 18,
        ];
    }

    public function styles(Worksheet $sheet)
    {
        $empresa = Empresa::first();
        $nombreEmpresa = $empresa->nombre ?? 'PREVENTRACK';

        $sheet->insertNewRowBefore(1, 3);
        $sheet->setCellValue('A1', $nombreEmpresa);
        $sheet->mergeCells('A1:H1');
        $sheet->setCellValue('A2', 'Reporte de Jornadas Laborales');
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
