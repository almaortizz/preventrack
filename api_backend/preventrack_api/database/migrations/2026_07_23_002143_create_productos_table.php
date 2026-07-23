<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('productos', function (Blueprint $table) {
            $table->id();
            $table->string('codigo', 50)->unique();
            $table->string('nombre', 150);
            $table->string('descripcion', 255)->nullable();
            $table->foreignId('categoria_id')->constrained('categorias');
            $table->decimal('precio_venta', 10, 2)->default(0);
            $table->decimal('costo', 10, 2)->default(0);
            $table->string('imagen', 255)->nullable();
            $table->unsignedInteger('stock')->default(0);
            $table->enum('estado', ['activo', 'inactivo'])->default('activo');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('productos');
    }
};
