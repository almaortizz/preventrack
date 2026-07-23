<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('clientes', function (Blueprint $table) {
            $table->id();
            $table->string('folio', 30)->unique();
            $table->string('nombre_negocio', 150);
            $table->string('propietario', 150)->nullable();
            $table->string('razon_social', 150)->nullable();
            $table->string('rfc', 20)->nullable();
            $table->string('telefono', 20)->nullable();
            $table->string('zona', 100)->nullable();
            $table->enum('estado', ['activo', 'inactivo'])->default('activo');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('clientes');
    }
};
