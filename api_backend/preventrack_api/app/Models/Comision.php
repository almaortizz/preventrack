<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Comision extends Model
{
    protected $fillable = [
        'usuario_id', 'cuota_id', 'monto', 'fecha_generada', 'estado',
    ];

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'usuario_id');
    }

    public function cuota()
    {
        return $this->belongsTo(Cuota::class, 'cuota_id');
    }
}
