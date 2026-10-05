<?php
// Guardar en: app/Models/RegistroGps.php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RegistroGps extends Model
{
    protected $table = 'registros_gps';

    protected $fillable = [
        'usuario_id', 'venta_id', 'detalle_ruta_id', 'tipo',
        'latitud', 'longitud', 'precision_m', 'distancia_m',
    ];

    public function usuario() { return $this->belongsTo(Usuario::class, 'usuario_id'); }
    public function venta()   { return $this->belongsTo(Venta::class, 'venta_id'); }

    /**
     * Crea un registro GPS a partir del request de la app.
     * Calcula la distancia (Haversine) contra el domicilio si hay coordenadas.
     */
    public static function desdeRequest($request, string $tipo, $domicilio = null, array $extra = []): self
    {
        $lat = $request->input('latitud');
        $lng = $request->input('longitud');
        $distancia = null;

        if ($lat !== null && $lng !== null && $domicilio && $domicilio->latitud && $domicilio->longitud) {
            $r = 6371000; // radio de la Tierra en metros
            $dLat = deg2rad($domicilio->latitud - $lat);
            $dLng = deg2rad($domicilio->longitud - $lng);
            $a = sin($dLat / 2) ** 2
               + cos(deg2rad($lat)) * cos(deg2rad($domicilio->latitud)) * sin($dLng / 2) ** 2;
            $distancia = round($r * 2 * atan2(sqrt($a), sqrt(1 - $a)), 2);
        }

        return self::create(array_merge([
            'usuario_id'  => $request->user()->id,
            'tipo'        => $tipo,
            'latitud'     => $lat,
            'longitud'    => $lng,
            'precision_m' => $request->input('precision'),
            'distancia_m' => $distancia,
        ], $extra));
    }
}
