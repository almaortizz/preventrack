<?php

namespace App\Http\Controllers;

use App\Models\Comision;
use App\Models\Cuota;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ComisionController extends Controller
{
    public function index(Request $request)
    {
        $query = Comision::with(['usuario', 'cuota']);

        // Un preventista solo ve sus propias comisiones
        if ((int) $request->user()->rol_id !== 1) {
            $query->where('usuario_id', $request->user()->id);
        } elseif ($request->filled('usuario_id')) {
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

    // Revisión manual desde el panel. La comisión también se genera sola al
    // registrar una entrega (VentaController@marcarEntregado).
    public function evaluarCuota(Cuota $cuota)
    {
        if ($cuota->cumplida) {
            throw ValidationException::withMessages([
                'cuota' => ['Esta cuota ya fue evaluada y marcada como cumplida.'],
            ]);
        }

        $comision = $cuota->evaluar();

        if (!$comision) {
            return response()->json([
                'message' => 'Aún no se alcanza la cuota.',
                'monto_alcanzado' => $cuota->monto_alcanzado,
                'monto_objetivo' => $cuota->monto_objetivo,
                'cuota' => $cuota,
            ]);
        }

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
