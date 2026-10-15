<?php

namespace App\Http\Controllers;

use App\Models\Cuota;
use App\Models\Usuario;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CuotaController extends Controller
{
    public function index(Request $request)
    {
        $query = Cuota::with('usuario');

        if ($request->filled('usuario_id')) {
            $query->where('usuario_id', $request->usuario_id);
        }

        if ($request->filled('cumplida')) {
            $query->where('cumplida', $request->boolean('cumplida'));
        }

        // Cuotas que se cruzan con la semana (lunes a sábado) de esa fecha
        if ($request->filled('semana')) {
            [$inicio, $fin] = $this->semanaLaboral(Carbon::parse($request->semana)->startOfWeek());
            $query->where('fecha_inicio_semana', '<=', $fin)
                ->where('fecha_fin_semana', '>=', $inicio);
        }

        return response()->json($query->orderByDesc('fecha_inicio_semana')->paginate(20));
    }

    public function store(Request $request)
    {
        $datos = $request->validate([
            'usuario_id' => 'required|exists:usuarios,id',
            'fecha_inicio_semana' => 'required|date',
            'monto_objetivo' => 'required|numeric|min:0',
            'monto_comision' => 'required|numeric|min:0',
        ]);

        [$inicio, $fin] = $this->semanaLaboral($datos['fecha_inicio_semana']);

        if ($this->tieneCuota($datos['usuario_id'], $inicio, $fin)) {
            throw ValidationException::withMessages([
                'usuario_id' => ['Este preventista ya tiene una cuota para esa semana.'],
            ]);
        }

        $cuota = Cuota::create([
            'usuario_id' => $datos['usuario_id'],
            'fecha_inicio_semana' => $inicio,
            'fecha_fin_semana' => $fin,
            'monto_objetivo' => $datos['monto_objetivo'],
            'monto_comision' => $datos['monto_comision'],
        ]);

        return response()->json($cuota, 201);
    }

    // Crea la cuota de la misma semana para varios preventistas a la vez.
    // Se salta a quien ya tenga cuota esa semana y lo informa.
    public function lote(Request $request)
    {
        $datos = $request->validate([
            'fecha_inicio_semana' => 'required|date',
            'cuotas' => 'required|array|min:1',
            'cuotas.*.usuario_id' => 'required|distinct|exists:usuarios,id',
            'cuotas.*.monto_objetivo' => 'required|numeric|min:0',
            'cuotas.*.monto_comision' => 'required|numeric|min:0',
        ]);

        [$inicio, $fin] = $this->semanaLaboral($datos['fecha_inicio_semana']);

        $creadas = [];
        $omitidos = [];

        DB::transaction(function () use ($datos, $inicio, $fin, &$creadas, &$omitidos) {
            foreach ($datos['cuotas'] as $item) {
                if ($this->tieneCuota($item['usuario_id'], $inicio, $fin)) {
                    $usuario = Usuario::find($item['usuario_id']);
                    $omitidos[] = trim($usuario->nombre . ' ' . $usuario->apellidos);
                    continue;
                }

                $creadas[] = Cuota::create([
                    'usuario_id' => $item['usuario_id'],
                    'fecha_inicio_semana' => $inicio,
                    'fecha_fin_semana' => $fin,
                    'monto_objetivo' => $item['monto_objetivo'],
                    'monto_comision' => $item['monto_comision'],
                ]);
            }
        });

        return response()->json([
            'message' => count($creadas) . ' cuota(s) creada(s).',
            'creadas' => $creadas,
            'omitidos' => $omitidos,
        ], 201);
    }

    public function show(Cuota $cuota)
    {
        return response()->json($cuota->load(['usuario', 'comisiones']));
    }

    public function update(Request $request, Cuota $cuota)
    {
        $datos = $request->validate([
            'monto_objetivo' => 'sometimes|numeric|min:0',
            'monto_comision' => 'sometimes|numeric|min:0',
        ]);

        $cuota->update($datos);

        return response()->json($cuota);
    }

    public function destroy(Cuota $cuota)
    {
        $cuota->delete();

        return response()->json(['message' => 'Cuota eliminada correctamente.']);
    }

    // Las cuotas son de lunes a sábado (el domingo no se trabaja).
    // Regresa [lunes, sábado] como fechas Y-m-d.
    private function semanaLaboral($fechaInicio): array
    {
        $lunes = Carbon::parse($fechaInicio)->startOfDay();

        if (!$lunes->isMonday()) {
            throw ValidationException::withMessages([
                'fecha_inicio_semana' => ['La cuota debe empezar en lunes.'],
            ]);
        }

        return [$lunes->toDateString(), $lunes->copy()->addDays(5)->toDateString()];
    }

    // ¿Ya tiene una cuota que se cruce con esa semana?
    private function tieneCuota($usuarioId, string $inicio, string $fin): bool
    {
        return Cuota::where('usuario_id', $usuarioId)
            ->where('fecha_inicio_semana', '<=', $fin)
            ->where('fecha_fin_semana', '>=', $inicio)
            ->exists();
    }
}
