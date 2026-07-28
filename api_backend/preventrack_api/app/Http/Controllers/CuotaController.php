<?php

namespace App\Http\Controllers;

use App\Models\Cuota;
use Illuminate\Http\Request;

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

        return response()->json($query->orderByDesc('fecha_inicio_semana')->paginate(20));
    }

    public function store(Request $request)
    {
        $datos = $request->validate([
            'usuario_id' => 'required|exists:usuarios,id',
            'fecha_inicio_semana' => 'required|date',
            'fecha_fin_semana' => 'required|date|after_or_equal:fecha_inicio_semana',
            'monto_objetivo' => 'required|numeric|min:0',
            'monto_comision' => 'required|numeric|min:0',
        ]);

        $cuota = Cuota::create($datos);

        return response()->json($cuota, 201);
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
}
