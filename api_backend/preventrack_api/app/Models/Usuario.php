<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class Usuario extends Authenticatable
{
    use Notifiable;

    protected $table = 'usuarios';

    protected $fillable = [
        'nombre', 'apellidos', 'edad', 'telefono',
        'usuario', 'password', 'rol_id', 'estado',
    ];

    protected $hidden = ['password'];

    public function rol()
    {
        return $this->belongsTo(Rol::class, 'rol_id');
    }

    public function ventasVendidas()
    {
        return $this->hasMany(Venta::class, 'preventista_vendedor_id');
    }

    public function ventasEntregadas()
    {
        return $this->hasMany(Venta::class, 'preventista_entrega_id');
    }

    public function cotizaciones()
    {
        return $this->hasMany(Cotizacion::class, 'usuario_id');
    }

    public function ubicaciones()
    {
        return $this->hasMany(Ubicacion::class, 'usuario_id');
    }

    public function visitas()
    {
        return $this->hasMany(Visita::class, 'usuario_id');
    }

    public function jornadas()
    {
        return $this->hasMany(Jornada::class, 'usuario_id');
    }

    public function cuotas()
    {
        return $this->hasMany(Cuota::class, 'usuario_id');
    }

    public function rutas()
    {
        return $this->hasMany(Ruta::class, 'usuario_id');
    }

    public function comisiones()
    {
        return $this->hasMany(Comision::class, 'usuario_id');
    }
}
