<?php

namespace App\Http\Controllers;

use App\Models\Usuario;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class UsuarioController extends Controller
{
    public function index(Request $request)
    {
        $query = Usuario::with('rol');

        if ($request->filled('nombre')) {
            $query->where(function ($q) use ($request) {
                $q->where('nombre', 'like', '%' . $request->nombre . '%')
                  ->orWhere('apellidos', 'like', '%' . $request->nombre . '%');
            });
        }

        if ($request->filled('usuario')) {
            $query->where('usuario', 'like', '%' . $request->usuario . '%');
        }

        if ($request->filled('rol_id')) {
            $query->where('rol_id', $request->rol_id);
        }

        if ($request->filled('estado')) {
            $query->where('estado', $request->estado);
        }

        return response()->json($query->orderBy('nombre')->paginate(20));
    }

    public function store(Request $request)
    {
        $datos = $request->validate([
            'nombre' => 'required|string|max:100',
            'apellidos' => 'required|string|max:100',
            'edad' => 'nullable|integer|min:0|max:255',
            'telefono' => 'nullable|string|max:20',
            'usuario' => 'required|string|max:50|unique:usuarios,usuario',
            'password' => 'required|string|min:6',
            'rol_id' => 'required|exists:roles,id',
            'estado' => 'nullable|in:activo,inactivo',
        ]);

        $datos['password'] = Hash::make($datos['password']);

        $usuario = Usuario::create($datos);

        return response()->json($usuario->load('rol'), 201);
    }

    public function show(Usuario $usuario)
    {
        return response()->json($usuario->load('rol'));
    }

    public function update(Request $request, Usuario $usuario)
    {
        $datos = $request->validate([
            'nombre' => 'sometimes|string|max:100',
            'apellidos' => 'sometimes|string|max:100',
            'edad' => 'nullable|integer|min:0|max:255',
            'telefono' => 'nullable|string|max:20',
            'usuario' => 'sometimes|string|max:50|unique:usuarios,usuario,' . $usuario->id,
            'password' => 'nullable|string|min:6',
            'rol_id' => 'sometimes|exists:roles,id',
            'estado' => 'sometimes|in:activo,inactivo',
        ]);

        if (! empty($datos['password'])) {
            $datos['password'] = Hash::make($datos['password']);
        } else {
            unset($datos['password']);
        }

        $usuario->update($datos);

        return response()->json($usuario->load('rol'));
    }

    // Bloquear (o desbloquear) un colaborador individual
    public function bloquear(Usuario $usuario)
    {
        $usuario->update(['estado' => 'inactivo']);

        return response()->json(['message' => 'Usuario bloqueado correctamente.', 'usuario' => $usuario]);
    }

    public function desbloquear(Usuario $usuario)
    {
        $usuario->update(['estado' => 'activo']);

        return response()->json(['message' => 'Usuario desbloqueado correctamente.', 'usuario' => $usuario]);
    }

    // Bloquear a TODOS los colaboradores de un jalón (bloqueo general)
    public function bloquearTodos(Request $request)
    {
        $query = Usuario::query();

        // Por seguridad, permite excluir al rol de administrador si se desea
        if ($request->filled('excluir_rol_id')) {
            $query->where('rol_id', '!=', $request->excluir_rol_id);
        }

        $afectados = $query->update(['estado' => 'inactivo']);

        return response()->json([
            'message' => 'Se bloquearon ' . $afectados . ' usuario(s) correctamente.',
        ]);
    }

    public function destroy(Usuario $usuario)
    {
        $usuario->delete();

        return response()->json(['message' => 'Usuario eliminado correctamente.']);
    }

    public function aceptarTerminos(Request $request)
    {
        $usuario = $request->user();
        $usuario->update([
            'terminos_aceptados' => true,
            'fecha_aceptacion_terminos' => now(),
        ]);

        return response()->json(['message' => 'Términos aceptados correctamente.', 'usuario' => $usuario]);
    }
}
