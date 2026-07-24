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
}
