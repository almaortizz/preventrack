<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Venta extends Model
{
    protected $fillable = [
        'numero_orden', 'domicilio_id', 'preventista_vendedor_id',
        'preventista_entrega_id', 'fecha_hora', 'total', 'estado',
        'latitud_registro', 'longitud_registro', 'fecha_entrega',
        'hora_entrega', 'motivo_cancelacion', 'impreso',
        'fecha_impresion', 'sincronizado', 'notas',
    ];

    protected $casts = [
    'fecha_hora' => 'datetime',
    'fecha_entrega' => 'date',
    'fecha_impresion' => 'datetime',
    'impreso' => 'boolean',
    'sincronizado' => 'boolean',
    ];

    public function domicilio()
    {
        return $this->belongsTo(Domicilio::class, 'domicilio_id');
    }

    public function vendedor()
    {
        return $this->belongsTo(Usuario::class, 'preventista_vendedor_id');
    }

    public function repartidor()
    {
        return $this->belongsTo(Usuario::class, 'preventista_entrega_id');
    }

    public function detalle()
    {
        return $this->hasMany(DetalleVenta::class, 'venta_id');
    }

    public function devoluciones()
    {
        return $this->hasMany(Devolucion::class, 'venta_id');
    }

    public function cotizacionOrigen()
    {
        return $this->hasOne(Cotizacion::class, 'venta_id');
    }

    public function visita()
    {
        return $this->hasOne(Visita::class, 'venta_id');
    }
}
