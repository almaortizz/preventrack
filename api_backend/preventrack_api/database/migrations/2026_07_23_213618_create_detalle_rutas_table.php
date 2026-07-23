<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('detalle_rutas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ruta_id')->constrained('rutas')->cascadeOnDelete();
            $table->foreignId('domicilio_id')->constrained('domicilios');
            $table->unsignedSmallInteger('orden_visita');
            $table->enum('estado', ['pendiente', 'visitada'])->default('pendiente');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('detalle_rutas');
    }
};
