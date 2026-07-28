<?php

namespace App\Http\Controllers;

use App\Models\Devolucion;
use App\Models\Venta;
use Illuminate\Http\Request;

class DevolucionController extends Controller
{
    public function index(Request $request)
    {
        $query = Devolucion::with(['venta', 'producto']);

        if ($request->filled('venta_id')) {
            $query->where('venta_id', $request->venta_id);
        }

        if ($request->filled('tipo')) {
            $query->where('tipo', $request->tipo);
        }

        return response()->json($query->orderByDesc('fecha')->paginate(20));
    }

    public function store(Request $request)
    {
        $datos = $request->validate([
            'venta_id' => 'required|exists:ventas,id',
            'producto_id' => 'required|exists:productos,id',
            'tipo' => 'required|in:devolucion,faltante',
            'cantidad' => 'required|integer|min:1',
            'motivo' => 'nullable|string|max:255',
        ]);

        $datos['fecha'] = now();

        $devolucion = Devolucion::create($datos);

        return response()->json($devolucion->load(['venta', 'producto']), 201);
    }

    public function show(Devolucion $devolucion)
    {
        return response()->json($devolucion->load(['venta', 'producto']));
    }

    public function destroy(Devolucion $devolucion)
    {
        $devolucion->delete();

        return response()->json(['message' => 'Registro de devolución eliminado correctamente.']);
    }
}
