<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cuotas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('usuarios');
            $table->date('fecha_inicio_semana');
            $table->date('fecha_fin_semana');
            $table->decimal('monto_objetivo', 10, 2);
            $table->decimal('monto_comision', 10, 2);
            $table->decimal('monto_alcanzado', 10, 2)->default(0);
            $table->boolean('cumplida')->default(false);
            $table->timestamps();

            $table->unique(['usuario_id', 'fecha_inicio_semana']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cuotas');
    }
};
