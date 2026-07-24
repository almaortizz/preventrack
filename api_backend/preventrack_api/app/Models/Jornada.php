<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Jornada extends Model
{
    protected $fillable = [
        'usuario_id', 'fecha', 'hora_inicio', 'latitud_inicio', 'longitud_inicio',
        'hora_inicio_comida', 'hora_fin_comida', 'hora_fin',
        'latitud_fin', 'longitud_fin',
    ];

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'usuario_id');
    }
}
