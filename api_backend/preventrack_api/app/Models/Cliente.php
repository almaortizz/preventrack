<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Cliente extends Model
{
    protected $fillable = [
        'folio', 'nombre_negocio', 'propietario', 'razon_social',
        'rfc', 'telefono', 'zona', 'estado',
    ];

    public function domicilios()
    {
        return $this->hasMany(Domicilio::class, 'cliente_id');
    }
}
