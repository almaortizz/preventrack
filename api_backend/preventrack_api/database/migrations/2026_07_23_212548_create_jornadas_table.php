<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('jornadas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('usuarios');
            $table->date('fecha');
            $table->dateTime('hora_inicio')->nullable();
            $table->decimal('latitud_inicio', 10, 7)->nullable();
            $table->decimal('longitud_inicio', 10, 7)->nullable();
            $table->dateTime('hora_inicio_comida')->nullable();
            $table->dateTime('hora_fin_comida')->nullable();
            $table->dateTime('hora_fin')->nullable();
            $table->decimal('latitud_fin', 10, 7)->nullable();
            $table->decimal('longitud_fin', 10, 7)->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('jornadas');
    }
};
