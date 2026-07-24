<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Empresa extends Model
{
    protected $table = 'empresa';

    protected $fillable = [
        'nombre', 'direccion', 'telefono', 'logo', 'rfc',
    ];
}
