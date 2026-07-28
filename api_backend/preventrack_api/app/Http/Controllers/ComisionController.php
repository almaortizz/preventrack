<?php

namespace App\Http\Controllers;

use App\Models\Comision;
use App\Models\Cuota;
use App\Models\Venta;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ComisionController extends Controller
{
    public function index(Request $request)
    {
        $query = Comision::with(['usuario', 'cuota']);

        if ($request->filled('usuario_id')) {
            $query->where('usuario_id', $request->usuario_id);
        }

        if ($request->filled('estado')) {
            $query->where('estado', $request->estado);
        }

        return response()->json($query->orderByDesc('fecha_generada')->paginate(20));
    }

    public function show(Comision $comision)
    {
        return response()->json($comision->load(['usuario', 'cuota']));
    }

    // Revisa el total vendido (pedidos entregados) dentro de la semana de la cuota,
    // y si alcanzó el objetivo, genera la comisión automáticamente.
    public function evaluarCuota(Cuota $cuota)
    {
        if ($cuota->cumplida) {
            throw ValidationException::withMessages([
                'cuota' => ['Esta cuota ya fue evaluada y marcada como cumplida.'],
            ]);
        }

        $totalVendido = Venta::where('preventista_vendedor_id', $cuota->usuario_id)
            ->where('estado', 'entregado')
            ->whereBetween('fecha_hora', [$cuota->fecha_inicio_semana, $cuota->fecha_fin_semana])
            ->sum('total');

        $cuota->update(['monto_alcanzado' => $totalVendido]);

        if ($totalVendido < $cuota->monto_objetivo) {
            return response()->json([
                'message' => 'Aún no se alcanza la cuota.',
                'monto_alcanzado' => $totalVendido,
                'monto_objetivo' => $cuota->monto_objetivo,
                'cuota' => $cuota,
            ]);
        }

        $cuota->update(['cumplida' => true]);

        $comision = Comision::create([
            'usuario_id' => $cuota->usuario_id,
            'cuota_id' => $cuota->id,
            'monto' => $cuota->monto_comision,
            'fecha_generada' => now()->toDateString(),
            'estado' => 'pendiente',
        ]);

        return response()->json([
            'message' => '¡Cuota cumplida! Comisión generada.',
            'comision' => $comision,
        ], 201);
    }

    // El administrador marca la comisión como pagada
    public function marcarPagada(Comision $comision)
    {
        $comision->update(['estado' => 'pagada']);

        return response()->json($comision);
    }
}
