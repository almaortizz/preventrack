<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('detalle_rutas', function (Blueprint $table) {
            $table->foreignId('venta_id')->nullable()->after('domicilio_id')->constrained('ventas')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('detalle_rutas', function (Blueprint $table) {
            $table->dropForeign(['venta_id']);
            $table->dropColumn('venta_id');
        });
    }
};
