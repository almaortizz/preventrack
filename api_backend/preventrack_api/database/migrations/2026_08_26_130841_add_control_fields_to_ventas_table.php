<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ventas', function (Blueprint $table) {
            $table->dateTime('fecha_inicio_creacion')->nullable()->after('notas');
            $table->dateTime('fecha_fin_creacion')->nullable()->after('fecha_inicio_creacion');
            $table->decimal('descuento', 10, 2)->default(0)->after('total');
        });
    }

    public function down(): void
    {
        Schema::table('ventas', function (Blueprint $table) {
            $table->dropColumn(['fecha_inicio_creacion', 'fecha_fin_creacion', 'descuento']);
        });
    }
};
