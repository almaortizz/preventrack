<?php

namespace App\Http\Controllers;

use App\Models\Cliente;
use Illuminate\Http\Request;

class ClienteController extends Controller
{
    public function index(Request $request)
    {
        $query = Cliente::with('domicilios');

        if ($request->filled('nombre_negocio')) {
            $query->where('nombre_negocio', 'like', '%' . $request->nombre_negocio . '%');
        }

        if ($request->filled('zona')) {
            $query->where('zona', 'like', '%' . $request->zona . '%');
        }

        return response()->json($query->paginate(20));
    }

    public function store(Request $request)
    {
        $datos = $request->validate([
            'folio' => 'required|string|max:30|unique:clientes,folio',
            'nombre_negocio' => 'required|string|max:150',
            'propietario' => 'nullable|string|max:150',
            'razon_social' => 'nullable|string|max:150',
            'rfc' => 'nullable|string|max:20',
            'telefono' => 'nullable|string|max:20',
            'zona' => 'nullable|string|max:100',
            'estado' => 'nullable|in:activo,inactivo',
        ]);

        $cliente = Cliente::create($datos);

        return response()->json($cliente, 201);
    }

    public function show(Cliente $cliente)
    {
        return response()->json($cliente->load('domicilios'));
    }

    public function update(Request $request, Cliente $cliente)
    {
        $datos = $request->validate([
            'folio' => 'sometimes|string|max:30|unique:clientes,folio,' . $cliente->id,
            'nombre_negocio' => 'sometimes|string|max:150',
            'propietario' => 'nullable|string|max:150',
            'razon_social' => 'nullable|string|max:150',
            'rfc' => 'nullable|string|max:20',
            'telefono' => 'nullable|string|max:20',
            'zona' => 'nullable|string|max:100',
            'estado' => 'sometimes|in:activo,inactivo',
        ]);

        $cliente->update($datos);

        return response()->json($cliente);
    }

    public function destroy(Cliente $cliente)
    {
        $cliente->delete();

        return response()->json(['message' => 'Cliente eliminado correctamente.']);
    }
}
