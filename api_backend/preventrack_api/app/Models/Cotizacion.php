<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Cotizacion extends Model
{
    protected $fillable = [
        'folio', 'domicilio_id', 'usuario_id', 'fecha_hora',
        'total', 'estado', 'venta_id',
    ];

    public function domicilio()
    {
        return $this->belongsTo(Domicilio::class, 'domicilio_id');
    }

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'usuario_id');
    }

    public function venta()
    {
        return $this->belongsTo(Venta::class, 'venta_id');
    }

    public function detalle()
    {
        return $this->hasMany(DetalleCotizacion::class, 'cotizacion_id');
    }
}
