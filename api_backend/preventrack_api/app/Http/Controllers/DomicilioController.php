<?php

namespace App\Http\Controllers;

use App\Models\Cliente;
use App\Models\Domicilio;
use Illuminate\Http\Request;

class DomicilioController extends Controller
{
    public function index(Cliente $cliente)
    {
        return response()->json($cliente->domicilios);
    }

    public function store(Request $request, Cliente $cliente)
    {
        $datos = $request->validate([
            'direccion' => 'required|string|max:255',
            'municipio' => 'nullable|string|max:100',
            'latitud' => 'nullable|numeric',
            'longitud' => 'nullable|numeric',
            'es_principal' => 'nullable|boolean',
            'estado' => 'nullable|in:activo,inactivo',
        ]);

        $domicilio = $cliente->domicilios()->create($datos);

        return response()->json($domicilio, 201);
    }

    public function show(Domicilio $domicilio)
    {
        return response()->json($domicilio->load('cliente'));
    }

    public function update(Request $request, Domicilio $domicilio)
    {
        $datos = $request->validate([
            'direccion' => 'sometimes|string|max:255',
            'municipio' => 'nullable|string|max:100',
            'latitud' => 'nullable|numeric',
            'longitud' => 'nullable|numeric',
            'es_principal' => 'nullable|boolean',
            'estado' => 'sometimes|in:activo,inactivo',
        ]);

        $domicilio->update($datos);

        return response()->json($domicilio);
    }

    public function destroy(Domicilio $domicilio)
    {
        $domicilio->delete();

        return response()->json(['message' => 'Domicilio eliminado correctamente.']);
    }
}
