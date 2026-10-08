<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('detalle_rutas', function (Blueprint $table) {
            $table->enum('estado', ['pendiente', 'visitada', 'no_disponible'])
                ->default('pendiente')->change();
        });

        Schema::table('visitas', function (Blueprint $table) {
            $table->enum('resultado', ['venta', 'sin_venta', 'no_disponible'])
                ->default('sin_venta')->change();
            $table->decimal('precision_m', 8, 2)->nullable()->after('longitud');   // precisión reportada por el GPS
            $table->decimal('distancia_m', 10, 2)->nullable()->after('precision_m'); // distancia al domicilio del cliente
        });
    }

    public function down(): void
    {
        // Antes de quitar el valor del enum, regresar los registros que lo usan
        DB::table('detalle_rutas')->where('estado', 'no_disponible')->update(['estado' => 'pendiente']);
        DB::table('visitas')->where('resultado', 'no_disponible')->update(['resultado' => 'sin_venta']);

        Schema::table('detalle_rutas', function (Blueprint $table) {
            $table->enum('estado', ['pendiente', 'visitada'])->default('pendiente')->change();
        });

        Schema::table('visitas', function (Blueprint $table) {
            $table->enum('resultado', ['venta', 'sin_venta'])->default('sin_venta')->change();
            $table->dropColumn(['precision_m', 'distancia_m']);
        });
    }
};
