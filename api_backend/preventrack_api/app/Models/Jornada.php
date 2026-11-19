<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;

class Jornada extends Model
{
    // Límite de una jornada abierta: al cumplirlo se cierra automáticamente.
    // Único lugar de la API donde se define (en la app: JornadaService).
    const HORAS_CIERRE_AUTOMATICO = 17;

    protected $fillable = [
        'usuario_id', 'fecha', 'hora_inicio', 'latitud_inicio', 'longitud_inicio',
        'hora_inicio_comida', 'hora_fin_comida', 'hora_fin', 'cierre_automatico',
        'latitud_fin', 'longitud_fin',
    ];

    // Las horas se dejan como texto (así las recibe la app); solo la marca es booleana
    protected $casts = [
        'cierre_automatico' => 'boolean',
    ];

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'usuario_id');
    }

    // Hora en que vence: hora_inicio + el límite
    public function limiteCierre(): ?Carbon
    {
        return $this->hora_inicio
            ? Carbon::parse($this->hora_inicio)->addHours(self::HORAS_CIERRE_AUTOMATICO)
            : null;
    }

    // Cierra la jornada si sigue abierta y ya cumplió el límite
    public function cerrarSiExcedeLimite(): bool
    {
        if ($this->hora_fin || !$this->hora_inicio || now()->lt($this->limiteCierre())) {
            return false;
        }

        $this->cerrarAutomaticamente();
        return true;
    }

    // hora_fin = inicio + límite (no la hora en que se detecta), sin
    // coordenadas de fin. Si estaba en comida, la comida termina al cierre
    // (así el tiempo de comida no se cuenta como trabajado).
    public function cerrarAutomaticamente(): void
    {
        $fin = $this->limiteCierre();
        $datos = [
            'hora_fin' => $fin,
            'cierre_automatico' => true,
            'latitud_fin' => null,
            'longitud_fin' => null,
        ];
        if ($this->hora_inicio_comida && !$this->hora_fin_comida) {
            $datos['hora_fin_comida'] = $fin;
        }

        $this->update($datos);
    }

    // Cierra las jornadas vencidas del usuario (se usa antes de revisar o
    // iniciar una jornada, en el monitoreo y al recibir ubicaciones)
    public static function cerrarVencidasDe($usuarioId): void
    {
        static::where('usuario_id', $usuarioId)
            ->whereNull('hora_fin')
            ->get()
            ->each(fn (Jornada $jornada) => $jornada->cerrarSiExcedeLimite());
    }

    // ¿Es la misma hora de inicio? La app la manda en UTC (con o sin
    // milisegundos) y la base la guarda en hora de México sin milisegundos
    // (MySQL redondea), así que se compara en la misma zona y con ±2 s.
    public function tieneInicio(?string $valor): bool
    {
        if (!$valor || !$this->hora_inicio) {
            return false;
        }

        try {
            $otro = Carbon::parse($valor)->setTimezone(config('app.timezone'));
        } catch (\Throwable) {
            return false;
        }

        return abs(Carbon::parse($this->hora_inicio)->diffInSeconds($otro)) <= 2;
    }
}
