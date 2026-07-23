<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
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
    }

    public function down(): void
    {
        Schema::dropIfExists('cotizaciones');
    }
};
