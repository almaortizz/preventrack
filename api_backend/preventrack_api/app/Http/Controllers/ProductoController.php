<?php

namespace App\Http\Controllers;

use App\Models\Producto;
use Illuminate\Http\Request;

class ProductoController extends Controller
{
    public function index(Request $request)
    {
        $query = Producto::with('categoria');

        if ($request->filled('nombre')) {
            $query->where('nombre', 'like', '%' . $request->nombre . '%');
        }

        if ($request->filled('codigo')) {
            $query->where('codigo', 'like', '%' . $request->codigo . '%');
        }

        if ($request->filled('categoria_id')) {
            $query->where('categoria_id', $request->categoria_id);
        }

        return response()->json($query->paginate(20));
    }

   public function store(Request $request)
{
    $datos = $request->validate([
        'codigo' => 'required|string|max:50|unique:productos,codigo',
        'nombre' => 'required|string|max:150',
        'descripcion' => 'nullable|string|max:255',
        'categoria_id' => 'required|exists:categorias,id',
        'precio_venta' => 'required|numeric|min:0',
        'costo' => 'required|numeric|min:0',
        'imagen' => 'nullable|image|max:4096',
        'stock' => 'nullable|integer|min:0',
        'estado' => 'nullable|in:activo,inactivo',
    ]);

    if ($request->hasFile('imagen')) {
        $datos['imagen'] = $request->file('imagen')->store('productos', 'public');
    }

    $producto = Producto::create($datos);

    return response()->json($producto, 201);
}

    public function show(Producto $producto)
    {
        return response()->json($producto->load('categoria'));
    }

public function update(Request $request, Producto $producto)
{
    $datos = $request->validate([
        'codigo' => 'sometimes|string|max:50|unique:productos,codigo,' . $producto->id,
        'nombre' => 'sometimes|string|max:150',
        'descripcion' => 'nullable|string|max:255',
        'categoria_id' => 'sometimes|exists:categorias,id',
        'precio_venta' => 'sometimes|numeric|min:0',
        'costo' => 'sometimes|numeric|min:0',
        'imagen' => 'nullable|image|max:4096',
        'stock' => 'sometimes|integer|min:0',
        'estado' => 'sometimes|in:activo,inactivo',
    ]);

    if ($request->hasFile('imagen')) {
        $datos['imagen'] = $request->file('imagen')->store('productos', 'public');
    }

    $producto->update($datos);

    return response()->json($producto);
}
    public function destroy(Producto $producto)
    {
        $producto->delete();

        return response()->json(['message' => 'Producto eliminado correctamente.']);
    }
}
