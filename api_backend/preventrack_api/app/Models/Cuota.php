<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;

class Cuota extends Model
{
    protected $fillable = [
        'usuario_id', 'fecha_inicio_semana', 'fecha_fin_semana',
        'monto_objetivo', 'monto_comision', 'monto_alcanzado', 'cumplida',
    ];

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'usuario_id');
    }

    public function comisiones()
    {
        return $this->hasMany(Comision::class, 'cuota_id');
    }

    // Cuota del preventista vigente en una fecha
    public static function vigente($usuarioId, $fecha): ?self
    {
        $dia = Carbon::parse($fecha)->toDateString();

        return self::where('usuario_id', $usuarioId)
            ->where('fecha_inicio_semana', '<=', $dia)
            ->where('fecha_fin_semana', '>=', $dia)
            ->first();
    }

    // Ventas que cuentan para la cuota: pedidos levantados por el
    // preventista dentro de la semana (por fecha del pedido) y ya
    // entregados. Incluye el último día completo.
    public static function ventasDeSemana($usuarioId, $inicio, $fin): float
    {
        return (float) Venta::where('preventista_vendedor_id', $usuarioId)
            ->where('estado', 'entregado')
            ->whereBetween('fecha_hora', [
                Carbon::parse($inicio)->startOfDay(),
                Carbon::parse($fin)->endOfDay(),
            ])
            ->sum('total');
    }

    public function ventasAlcanzadas(): float
    {
        return self::ventasDeSemana($this->usuario_id, $this->fecha_inicio_semana, $this->fecha_fin_semana);
    }

    // Actualiza lo alcanzado y, si ya se llegó al objetivo, genera la
    // comisión (una sola vez por cuota). Regresa la comisión generada.
    public function evaluar(): ?Comision
    {
        $alcanzado = $this->ventasAlcanzadas();
        $this->update(['monto_alcanzado' => $alcanzado]);

        if ($this->cumplida || $alcanzado < $this->monto_objetivo || $this->comisiones()->exists()) {
            return null;
        }

        $this->update(['cumplida' => true]);

        return Comision::create([
            'usuario_id' => $this->usuario_id,
            'cuota_id' => $this->id,
            'monto' => $this->monto_comision,
            'fecha_generada' => now()->toDateString(),
            'estado' => 'pendiente',
        ]);
    }
}
