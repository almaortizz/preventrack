<?php
// Guardar en: database/migrations/
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('registros_gps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('usuarios');
            $table->foreignId('venta_id')->nullable()->constrained('ventas');
            $table->foreignId('detalle_ruta_id')->nullable()->constrained('detalle_rutas');
            $table->enum('tipo', ['entrega', 'no_entregado', 'visita', 'no_disponible']);
            $table->decimal('latitud', 10, 7)->nullable();
            $table->decimal('longitud', 10, 7)->nullable();
            $table->decimal('precision_m', 8, 2)->nullable();   // precisión reportada por el GPS
            $table->decimal('distancia_m', 10, 2)->nullable();  // distancia al domicilio del cliente
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('registros_gps');
    }
};
