<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Producto extends Model
{
    protected $fillable = [
        'codigo', 'nombre', 'descripcion', 'categoria_id',
        'precio_venta', 'costo', 'imagen', 'stock', 'estado',
    ];

    public function categoria()
    {
        return $this->belongsTo(Categoria::class, 'categoria_id');
    }

    public function detalleVentas()
    {
        return $this->hasMany(DetalleVenta::class, 'producto_id');
    }

    public function detalleCotizaciones()
    {
        return $this->hasMany(DetalleCotizacion::class, 'producto_id');
    }

    public function devoluciones()
    {
        return $this->hasMany(Devolucion::class, 'producto_id');
    }
}
