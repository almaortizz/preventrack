<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Domicilio extends Model
{
    protected $fillable = [
        'cliente_id', 'direccion', 'municipio', 'latitud',
        'longitud', 'es_principal', 'estado',
    ];

    public function cliente()
    {
        return $this->belongsTo(Cliente::class, 'cliente_id');
    }

    public function ventas()
    {
        return $this->hasMany(Venta::class, 'domicilio_id');
    }

    public function cotizaciones()
    {
        return $this->hasMany(Cotizacion::class, 'domicilio_id');
    }

    public function visitas()
    {
        return $this->hasMany(Visita::class, 'domicilio_id');
    }

    public function detalleRutas()
    {
        return $this->hasMany(DetalleRuta::class, 'domicilio_id');
    }
}
