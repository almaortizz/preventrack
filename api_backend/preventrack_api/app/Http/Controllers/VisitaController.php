<?php

namespace App\Http\Controllers;

use App\Models\Visita;
use Illuminate\Http\Request;

class VisitaController extends Controller
{
    public function index(Request $request)
    {
        $query = Visita::with(['usuario', 'domicilio.cliente', 'venta']);

        if ($request->filled('usuario_id')) {
            $query->where('usuario_id', $request->usuario_id);
        }

        if ($request->filled('fecha')) {
            $query->whereDate('fecha_hora', $request->fecha);
        }

        if ($request->filled('resultado')) {
            $query->where('resultado', $request->resultado);
        }

        return response()->json($query->orderByDesc('fecha_hora')->paginate(20));
    }

    public function store(Request $request)
    {
        $datos = $request->validate([
            'usuario_id' => 'required|exists:usuarios,id',
            'domicilio_id' => 'required|exists:domicilios,id',
            'latitud' => 'nullable|numeric',
            'longitud' => 'nullable|numeric',
            'resultado' => 'required|in:venta,sin_venta',
            'venta_id' => 'nullable|exists:ventas,id',
        ]);

        $datos['fecha_hora'] = now();

        $visita = Visita::create($datos);

        return response()->json($visita->load(['usuario', 'domicilio.cliente']), 201);
    }

    public function show(Visita $visita)
    {
        return response()->json($visita->load(['usuario', 'domicilio.cliente', 'venta']));
    }

    public function destroy(Visita $visita)
    {
        $visita->delete();

        return response()->json(['message' => 'Visita eliminada correctamente.']);
    }
}
