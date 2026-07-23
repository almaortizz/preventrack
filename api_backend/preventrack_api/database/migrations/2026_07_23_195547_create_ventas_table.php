<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ventas', function (Blueprint $table) {
            $table->id();
            $table->string('numero_orden', 30)->unique();
            $table->foreignId('domicilio_id')->constrained('domicilios');
            $table->foreignId('preventista_vendedor_id')->constrained('usuarios');
            $table->foreignId('preventista_entrega_id')->nullable()->constrained('usuarios');
            $table->dateTime('fecha_hora');
            $table->decimal('total', 10, 2)->default(0);
            $table->enum('estado', ['pendiente', 'en_ruta', 'entregado', 'cancelado'])->default('pendiente');

            // GPS al momento de registrar el pedido
            $table->decimal('latitud_registro', 10, 7)->nullable();
            $table->decimal('longitud_registro', 10, 7)->nullable();

            // se llenan al finalizar la entrega
            $table->date('fecha_entrega')->nullable();
            $table->time('hora_entrega')->nullable();

            $table->string('motivo_cancelacion', 255)->nullable();

            $table->boolean('impreso')->default(false);
            $table->dateTime('fecha_impresion')->nullable();

            $table->boolean('sincronizado')->default(true);
            $table->text('notas')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ventas');
    }
};
