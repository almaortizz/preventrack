<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DetalleRuta extends Model
{
    protected $table = 'detalle_rutas';

    public $timestamps = false;

    protected $fillable = ['ruta_id', 'domicilio_id', 'orden_visita', 'estado'];

    public function ruta()
    {
        return $this->belongsTo(Ruta::class, 'ruta_id');
    }

    public function domicilio()
    {
        return $this->belongsTo(Domicilio::class, 'domicilio_id');
    }
}
