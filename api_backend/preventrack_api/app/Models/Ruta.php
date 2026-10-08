<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Ruta extends Model
{
    protected $fillable = ['usuario_id', 'fecha', 'estado'];

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'usuario_id');
    }

    public function detalle()
    {
        return $this->hasMany(DetalleRuta::class, 'ruta_id');
    }

    // Si ya no quedan paradas pendientes la ruta se marca finalizada;
    // las "no_disponible" cuentan como atendidas
    public function actualizarEstado(): void
    {
        $pendientes = $this->detalle()->where('estado', 'pendiente')->count();

        if ($pendientes === 0) {
            $this->update(['estado' => 'finalizada']);
        } elseif ($this->estado === 'planeada') {
            $this->update(['estado' => 'en_curso']);
        }
    }

    // Solo el preventista asignado o un admin pueden atender la ruta
    public function puedeAtender(Usuario $usuario): bool
    {
        return (int) $this->usuario_id === (int) $usuario->id || (int) $usuario->rol_id === 1;
    }
}
