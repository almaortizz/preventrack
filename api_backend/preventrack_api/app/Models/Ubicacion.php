<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Ubicacion extends Model
{
    const UPDATED_AT = null;

    protected $fillable = [
        'usuario_id', 'latitud', 'longitud', 'fecha_hora', 'sincronizado',
    ];

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'usuario_id');
    }
}
