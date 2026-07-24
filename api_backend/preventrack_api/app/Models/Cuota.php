<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Cuota extends Model
{
    protected $fillable = [
        'usuario_id', 'fecha_inicio_semana', 'fecha_fin_semana',
        'monto_objetivo', 'monto_comision', 'monto_alcanzado', 'cumplida',
    ];

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'usuario_id');
    }

    public function comisiones()
    {
        return $this->hasMany(Comision::class, 'cuota_id');
    }
}
