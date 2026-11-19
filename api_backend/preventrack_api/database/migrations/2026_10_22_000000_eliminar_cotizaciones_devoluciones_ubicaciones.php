<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// Quita funciones que existían pero no se usaban: cotizaciones, devoluciones y
// el historial de ubicaciones (el monitoreo usa usuarios.ultima_latitud/longitud).
// down() las vuelve a crear exactamente como estaban.
return new class extends Migration
{
    private array $tablas = ['detalle_cotizaciones', 'cotizaciones', 'devoluciones', 'ubicaciones'];

    public function up(): void
    {
        // Candado: si alguna tabla tiene registros no se borra nada
        foreach ($this->tablas as $tabla) {
            if (Schema::hasTable($tabla) && DB::table($tabla)->exists()) {
                throw new RuntimeException(
                    "La tabla {$tabla} tiene registros; no se eliminó ninguna tabla. Respáldalos y revísalos antes de continuar."
                );
            }
        }

        // Orden por llaves foráneas: el detalle antes que la cotización
        foreach ($this->tablas as $tabla) {
            Schema::dropIfExists($tabla);
        }
    }

    public function down(): void
    {
        Schema::create('cotizaciones', function (Blueprint $table) {
            $table->id();
            $table->string('folio', 30)->unique();
            $table->foreignId('domicilio_id')->constrained('domicilios');
            $table->foreignId('usuario_id')->constrained('usuarios');
            $table->dateTime('fecha_hora');
            $table->decimal('total', 10, 2)->default(0);
            $table->enum('estado', ['cotizada', 'convertida', 'cancelada'])->default('cotizada');
            $table->foreignId('venta_id')->nullable()->constrained('ventas');
            $table->timestamps();
        });

        Schema::create('detalle_cotizaciones', function (Blueprint $table) {
            $table->id();
            $table->foreignId('cotizacion_id')->constrained('cotizaciones')->cascadeOnDelete();
            $table->foreignId('producto_id')->constrained('productos');
            $table->unsignedInteger('cantidad');
            $table->decimal('precio_unitario', 10, 2);
            $table->decimal('subtotal', 10, 2);
            $table->timestamps();
        });

        Schema::create('devoluciones', function (Blueprint $table) {
            $table->id();
            $table->foreignId('venta_id')->constrained('ventas');
            $table->foreignId('producto_id')->constrained('productos');
            $table->enum('tipo', ['devolucion', 'faltante'])->default('devolucion');
            $table->unsignedInteger('cantidad');
            $table->string('motivo', 255)->nullable();
            $table->dateTime('fecha');
            $table->timestamp('created_at')->useCurrent();
        });

        Schema::create('ubicaciones', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('usuarios');
            $table->decimal('latitud', 10, 7);
            $table->decimal('longitud', 10, 7);
            $table->dateTime('fecha_hora');
            $table->boolean('sincronizado')->default(true);
            $table->timestamp('created_at')->useCurrent();
        });
    }
};
